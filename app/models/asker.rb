class Asker < User
  belongs_to :client
  has_many :questions, :foreign_key => :created_for_asker_id
  belongs_to :new_user_question, :class_name => 'Question', :foreign_key => :new_user_q_id

  default_scope where(:role => 'asker')

  # cached queries

  def self.by_twi_screen_name
    Rails.cache.fetch('askers_by_twi_screen_name', :expires_in => 5.minutes){Asker.order("twi_screen_name ASC").all}
  end

  def self.ids
    Rails.cache.fetch('asker_ids', :expires_in => 5.minutes){Asker.all.collect(&:id)}
  end

  def unresponded_count
    posts = Post.where("posts.requires_action = ? AND posts.in_reply_to_user_id = ? AND (posts.spam is null or posts.spam = ?) AND posts.user_id not in (?)", true, id, false, Asker.ids)
    count = posts.not_spam.where("interaction_type = 2").count
    count += posts.not_spam.where("interaction_type = 4").count :user_id, :distinct => true

    count
  end

  def self.unresponded_counts
    mention_counts = Post.mentions.requires_action.not_us.not_spam.not_ugc.group('in_reply_to_user_id').count
    dm_counts = Post.not_ugc.not_us.dms.requires_action.not_spam.group('in_reply_to_user_id').count :user_id, :distinct => true

    counts = {}
    Asker.ids.each{|id| counts[id] = 0}
    counts = counts.merge(mention_counts)
    counts = counts.merge(dm_counts){|key, v1, v2| v1 + v2}
    counts
  end

  def publish_question
    queue = self.publication_queue
    unless queue.blank?
      publication = queue.publications.order(:id)[queue.index]
      PROVIDERS.each { |provider| Post.publish(provider, self, publication) }
      queue.increment_index(self.posts_per_day)
      Rails.cache.delete("askers:#{self.id}:show")
    end
  end

  def update_followers
  	# Get lists of user ids from twitter + wisr
  	twi_follower_ids = Post.twitter_request { self.twitter.follower_ids.ids }
  	wisr_follower_ids = followers.collect(&:twi_user_id)

  	# Add new followers in wisr
  	(twi_follower_ids - wisr_follower_ids).each { |new_user_twi_id| add_follower(User.find_or_create_by_twi_user_id(new_user_twi_id)) }

		# Remove unfollowers from asker follow association  	
  	unfollowed_users = User.where("twi_user_id in (?)", (wisr_follower_ids - twi_follower_ids))
  	unfollowed_users.each { |unfollowed_user| remove_follower(unfollowed_user) }
  	
  	return twi_follower_ids 
  end 

  def add_follower user
    unless followers.include? user
      followers << user 
      user.segment
    end
  end

  def remove_follower user
    followers.delete(user)
    user.follows.delete(self)
    user.segment
  end

  def self.post_aggregate_activity
    current_cache = (Rails.cache.read("aggregate activity") ? Rails.cache.read("aggregate activity").dup : {})
    current_cache.keys.each do |user_id|
      user_cache = current_cache[user_id]
      user_cache[:askers].keys.each do |asker_id|
        asker_cache = user_cache[:askers][asker_id]
        if asker_cache[:last_answer_at] < 5.minutes.ago and asker_cache[:count] > 0
          asker = Asker.find(asker_id)
          script = Asker.get_aggregate_post_response_script(asker_cache[:count], asker_cache[:correct])
          Post.tweet(asker, script, {
            :reply_to => user_cache[:twi_screen_name],
            :interaction_type => 2, 
            :link_type => "agg", 
            :in_reply_to_user_id => user_id,
            :intention => 'post aggregate activity'
          })
          current_cache[user_id][:askers].delete(asker_id)
          sleep(3)
        end
      end
      current_cache.delete(user_id) if current_cache[user_id][:askers].keys.blank?
    end
    Rails.cache.write("aggregate activity", current_cache)
  end

  def self.get_aggregate_post_response_script(answer_count, correct_count)
    if correct_count > 20
      script = AGGREGATE_POST_RESPONSES[:tons_correct].sample.gsub("{num_correct}", correct_count.to_s)
    elsif correct_count > 3
      script = AGGREGATE_POST_RESPONSES[:many_correct].sample.gsub("{num_correct}", correct_count.to_s)
    elsif correct_count > 1
      script = AGGREGATE_POST_RESPONSES[:multiple_correct].sample.gsub("{num_correct}", correct_count.to_s)
    elsif answer_count > 1
      script = AGGREGATE_POST_RESPONSES[:multiple_answers].sample.gsub("{count}", answer_count.to_s)
    else
      script = AGGREGATE_POST_RESPONSES[:one_answer].sample
    end
    script 
  end

  def self.reengage_inactive_users
  	# Strategy definition, currently overriden in compile_recipients_by_asker
  	strategy = [3, 7, 10]

		# Set time ranges
    buffer = 3.days
    begin_range = (Time.now - 2.days)
    end_range = (Time.now - (20.days + buffer))

    # Get disengaging users, recent reengagement attempts
    disengaging_users, recent_reengagements = Asker.get_disengaging_users_and_reengagements(begin_range, end_range)

		# Compile recipients by asker, filter out recently engaged, pick asker to send from
    asker_recipients = Asker.compile_recipients_by_asker(strategy, disengaging_users, recent_reengagements)

		# Get popular publications
		Post.includes(:conversations).where("posts.user_id in (?) and posts.created_at > ? and posts.interaction_type = 1", asker_recipients.keys, 2.days.ago).group_by(&:user_id).each do |user_id, posts|
      asker_recipients[user_id][:publication] = posts.sort_by{|p| p.conversations.size}.last.publication
    end

    # Send reengagement tweets
    Asker.send_reengagement_tweets(asker_recipients) 
  end 

  def self.get_disengaging_users_and_reengagements(begin_range, end_range)
    # Get disengaging users
    disengaging_users = User.includes(:posts)\
      .where("users.activity_segment <> 7")\
      .where("users.last_answer_at is not null")\
      .where("users.last_interaction_at > ? and users.last_interaction_at < ?", end_range, begin_range)

    # Get recently sent re-engagements
    recent_reengagements = Post.where("in_reply_to_user_id in (?)", disengaging_users.collect(&:id))\
      .where("intention = 'reengage inactive'")\
      .where("created_at > ?", end_range)\
      .order("created_at DESC")\
      .group_by(&:in_reply_to_user_id)

    return disengaging_users, recent_reengagements
  end

  def self.compile_recipients_by_asker(strategy, disengaging_users, recent_reengagements, asker_recipients = {})
    disengaging_users.each do |user|
      test_option = Post.create_split_test(user.id, "reengagement interval", "3/7/10", "2/5/7", "5/7/7")
      strategy = test_option.split("/").map { |e| e.to_i }
      user_reengagments = (recent_reengagements[user.id] || []).select { |p| p.created_at > user.last_interaction_at }.sort_by(&:created_at)      
      asker_id = user.posts.answers.where("in_reply_to_user_id in (?)", user.follows.collect(&:id)).collect(&:in_reply_to_user_id).sample
      next unless next_checkpoint = strategy[user_reengagments.size] and asker_id
      time_since_last_touchpoint = (Time.now - (user_reengagments.present? ? user_reengagments.last.created_at : user.last_interaction_at))
      if time_since_last_touchpoint > next_checkpoint.days
        asker_recipients[asker_id] ||= {:recipients => []}
        asker_recipients[asker_id][:recipients] << {:user => user, :interval => strategy[user_reengagments.size], :strategy => test_option}
        # puts "sending to #{user.twi_screen_name}"
        # puts "time_since_last_touchpoint = #{time_since_last_touchpoint}"
        # puts "next checkpoint = #{next_checkpoint.days.to_i} (#{strategy[user_reengagments.size]})"
        # puts "strategy: #{strategy}"
      end
    end
    asker_recipients
  end

  def self.send_reengagement_tweets(asker_recipients)
    asker_recipients.each do |asker_id, recipient_data|
      asker = Asker.find(asker_id)
      follower_ids = asker.update_followers()
      publication = recipient_data[:publication]
      next unless asker and publication
      question = publication.question
      recipient_data[:recipients].each do |user_hash|
        user = user_hash[:user]
        next unless follower_ids.include? user.twi_user_id
        option_text = Post.create_split_test(user.id, "reengage last week inactive", "Pop quiz:", "A question for you:", "Do you know the answer?", "Quick quiz:", "We've missed you!")       
        # puts "sending reengagement to #{user.twi_screen_name} (interval = #{user_hash[:interval]})"
        Post.tweet(asker, "#{option_text} #{question.text}", {
          :reply_to => user.twi_screen_name,
          :long_url => "http://wisr.com/feeds/#{asker.id}/#{publication.id}",
          :in_reply_to_user_id => user.id,
          :posted_via_app => true,
          :publication_id => publication.id,  
          :requires_action => false,
          :interaction_type => 2,
          :link_to_parent => false,
          :link_type => "reengage",
          :intention => "reengage inactive",
          :include_answers => true
        })
        Mixpanel.track_event "reengage inactive", {:distinct_id => user.id, :interval => user_hash[:interval], :strategy => user_hash[:strategy]}
        sleep(1)
      end
    end  
  end

  def self.engage_new_users
    # Send DMs to new users
    Asker.dm_new_followers

    # Send mentions to new users
    Asker.mention_new_users
  end

  def self.dm_new_followers
    askers = Asker.all
    # new_user_questions = Question.find(askers.collect(&:new_user_q_id)).group_by(&:created_for_asker_id)
    new_user_questions = Question.where(:id => askers.collect(&:new_user_q_id)).group_by(&:created_for_asker_id)
    askers.each do |asker|
      stop = false
      new_followers = Post.twitter_request { asker.twitter.follower_ids.ids.first(50) } || []
      new_followers.each do |tid|
        break if stop
        follow_response = Post.twitter_request { asker.twitter.follow(tid) }
        stop = true if follow_response.blank?
        sleep(1)
        user = User.find_or_create_by_twi_user_id(tid)
        asker.add_follower(user)
        next if new_user_questions[asker.id].blank? or asker.posts.where(:provider => 'twitter', :interaction_type => 4, :in_reply_to_user_id => user.id).count > 0
        question = new_user_questions[asker.id][0]

        response_text = "Here's your first question! #{question.text}"
        response_text += " (#{question.answers.shuffle.collect {|a| a.text}.join('; ')})" if INCLUDE_ANSWERS.include? asker.id

        Post.dm(asker, user, response_text, {:intention => "initial question dm"})
        Mixpanel.track_event "DM question to new follower", {
          :distinct_id => user.id,
          :account => asker.twi_screen_name
        }
        sleep(1)   
      end
    end    
  end

  def self.mention_new_users
    askers = Asker.all
    answered_dm_users = User.where("learner_level = 'dm answer' and created_at > ?", 1.week.ago).includes(:posts)
    app_posts = Post.where("in_reply_to_user_id in (?) and intention = 'new user question mention'", answered_dm_users.collect(&:id)).group_by(&:in_reply_to_user_id)
    popular_asker_publications = {}
    answered_dm_users.each do |user|
      if app_posts[user.id].blank?
        asker = askers.select { |a| a.id == user.posts.first.in_reply_to_user_id }.first
        unless publication = popular_asker_publications[asker.id]
          if popular_post = asker.posts.includes(:conversations => {:publication => :question}).where("posts.created_at > ? and posts.interaction_type = 1 and questions.id <> ?", 1.week.ago, asker.new_user_q_id).sort_by {|p| p.conversations.size}.last
            publication_id = popular_post.publication_id
          else
            publication_id = asker.posts.where("interaction_type = 1").order("created_at DESC").limit(1).first.publication_id
          end
          publication = Publication.includes(:question).find(publication_id)
          popular_asker_publications[asker.id] = publication
        end
        Post.tweet(asker, "Next question! #{publication.question.text}", {
          :reply_to => user.twi_screen_name,
          :long_url => "#{URL}/feeds/#{asker.id}/#{publication.id}", 
          :interaction_type => 2, 
          :link_type => "mention_question", 
          :in_reply_to_user_id => user.id,
          :publication_id => publication.id,
          :intention => "new user question mention",
          :posted_via_app => true,
          :requires_action => false,
          :link_to_parent => false        
        })
        Mixpanel.track_event "new user question mention", {
          :distinct_id => user.id, 
          :account => asker.twi_screen_name
        }
      end 
    end
  end

  def get_DM_answer_nudge_script feedback, user_id
    script = Post.create_split_test(user_id, "DM answer response script", 
      "{feedback}",
      "{feedback} I tweet new questions frequently, check them out at {twitter feed link}.",
      "{feedback} Try out some more questions at {wisr feed link}",
      "{feedback} I'll tweet you another question shortly, hold on...",
      "{feedback} Check my tweets for more Qs, you can respond on Twitter or follow the links to answer on our website!",
      "{feedback} Here's your next question: {wisr question link}"
    )  
    script.gsub! "{feedback}", feedback
    script.gsub! "{twitter feed link}", "twitter.com/#{twi_screen_name}"
    script.gsub! "{wisr feed link}", "wisr.com/feeds/#{id}"
    
    if script.include? "{wisr question link}"
      script.gsub! "{wisr question link}", "wisr.com/feeds/#{id}/#{publications.published.order('created_at DESC').first.id}"
    end
    script
  end

  def self.reengage_incorrect_answerers
    askers = User.askers
    current_time = Time.now
    range_begin = 24.hours.ago
    range_end = 23.hours.ago
    
    puts "Current time: #{current_time}"
    puts "range = #{range_begin} - #{range_end}"
    
    recent_posts = Post.where("user_id is not null and ((correct = ? and created_at > ? and created_at < ? and interaction_type = 2) or ((intention = ? or intention = ?) and created_at > ?))", false, range_begin, range_end, 'reengage', 'incorrect answer follow up', range_end).includes(:user)
    user_grouped_posts = recent_posts.group_by(&:user_id)
    asker_ids = askers.collect(&:id)
    user_grouped_posts.each do |user_id, posts|
      # should ensure only one tweet per user as well here?
      next if asker_ids.include? user_id or recent_posts.where("(intention = ? or intention = ?) and in_reply_to_user_id = ?", 'reengage', 'incorrect answer follow up', user_id).present?
      incorrect_post = posts.sample
      # eww, think we need a cleaner way to access the question associated w/ a post
      question = incorrect_post.conversation.publication.question
      asker = User.askers.find(incorrect_post.in_reply_to_user_id)
      # always link? another A/B test?
      # existing re-engages should be changed to follow-up!!!
      Post.tweet(asker, "Try this one again: #{question.text}", {
        :reply_to => incorrect_post.user.twi_screen_name,
        :long_url => "http://wisr.com/questions/#{question.id}/#{question.slug}",
        :in_reply_to_post_id => incorrect_post.id,
        :in_reply_to_user_id => user_id,
        :conversation_id => incorrect_post.conversation_id,
        :posted_via_app => true, 
        :requires_action => false,
        :interaction_type => 2,
        :link_to_parent => false,
        :link_type => "follow_up",
        :intention => "incorrect answer follow up"
      })  
      Mixpanel.track_event "incorrect answer follow up sent", {:distinct_id => user_id}
      puts "sending follow-up message to: #{user_id}"
      sleep(1)
    end
    puts "\n"       
  end 

  def update_aggregate_activity_cache user, correct
    current_cache = (Rails.cache.read("aggregate activity") ? Rails.cache.read("aggregate activity").dup : {})
    current_cache[user.id] ||= {:askers => {}}
    current_cache[user.id][:twi_screen_name] = user.twi_screen_name
    current_cache[user.id][:askers][self.id] ||= Hash.new(0)
    current_cache[user.id][:askers][self.id][:last_answer_at] = Time.now
    current_cache[user.id][:askers][self.id][:count] += 1
    current_cache[user.id][:askers][self.id][:correct] += 1 if correct
    Rails.cache.write("aggregate activity", current_cache)
  end

  def app_response user_post, correct, options = {}
    publication = user_post.conversation.try(:publication) || user_post.parent.try(:publication)
    answerer = user_post.user

    response_text = options[:response_text] || self.generate_response(correct)
    resource_url = nil

    if options[:response_text].blank?
      if correct and options[:post_aggregate_activity].blank?
        cleaned_user_post = user_post.text.gsub /@[A-Za-z0-9_]* /, ""
        cleaned_user_post = "#{cleaned_user_post[0..47]}..." if cleaned_user_post.size > 50
        response_text += " RT '#{cleaned_user_post}'" 
      elsif !correct
        answer_text = Answer.where("question_id = ? and correct = ?", publication.question_id, true).first().text
        answer_text = "#{answer_text[0..77]}..." if answer_text.size > 80
        response_text = "#{['Sorry', 'Not quite', 'No'].sample}, I was looking for '#{answer_text}'"
        short_resource_url = Post.shorten_url("#{URL}/posts/#{publication.id}/refer", 'wisr', 'res', answerer.twi_screen_name) if publication.question.resource_url
        response_text += ". Learn more at #{short_resource_url}" if short_resource_url.present?        
      end
    end 

    if options[:post_aggregate_activity] == true
      app_post = Post.create({
        :user_id => self.id,
        :provider => 'wisr',
        :text => response_text,
        :in_reply_to_post_id => user_post.id,
        :in_reply_to_user_id => answerer.id,
        :posted_via_app => true, 
        :requires_action => false,
        :interaction_type => 2,
        :intention => 'grade'
      })
    else
      app_post = Post.tweet(self, response_text, {
        :reply_to => answerer.twi_screen_name,
        :long_url => "#{URL}/feeds/#{self.id}/#{publication.id}", 
        :interaction_type => 2, 
        :link_type => correct ? "cor" : "inc", 
        :in_reply_to_post_id => user_post.id, 
        :in_reply_to_user_id => answerer.id,
        :link_to_parent => options[:link_to_parent], 
        :resource_url => correct ? nil : resource_url,
        :wisr_question => publication.question.resource_url ? false : true,
        :intention => 'grade'
      })        
    end

    # Mark user's post as responded to
    user_post.update_attributes(:requires_action => false, :correct => correct)

    # Trigger after answer actions
    after_answer_filter(answerer, user_post)

    # Trigger split tests, MP events
    update_metrics(answerer, user_post, publication, {:autoresponse => options[:autoresponse]})

    app_post
  end   

  def auto_respond user_post
    if Post.create_split_test(user_post.user_id, "auto respond", "true", "false") == "true" and user_post.autocorrect.present?
      asker_response = app_response(user_post, user_post.autocorrect, {:link_to_parent => false, :autoresponse => true})
      conversation = user_post.conversation || Conversation.create(:publication_id => user_post.publication_id, :post_id => user_post.in_reply_to_post_id, :user_id => user_post.user_id)
      conversation.posts << user_post
      conversation.posts << asker_response
    end
  end

  def after_answer_filter answerer, user_post
    request_ugc(answerer)
    Client.nudge answerer, self, user_post
    Post.trigger_split_test(answerer.id, "DM answer response script")
  end 

  def update_metrics answerer, user_post, publication, options = {}
    in_reply_to = nil
    strategy = nil
    if user_post.posted_via_app
      # Check if in response to re-engage message
      last_inactive_reengagement = Post.where("intention = ? and in_reply_to_user_id = ? and publication_id = ?", 'reengage inactive', answerer.id, publication.id).order("created_at DESC").limit(1).first
      if last_inactive_reengagement.present? and Post.joins(:conversation).where("posts.id <> ? and posts.user_id = ? and posts.correct is not null and posts.created_at > ? and conversations.publication_id = ?", user_post.id, answerer.id, last_inactive_reengagement.created_at, publication.id).blank?
        Post.trigger_split_test(answerer.id, 'reengage last week inactive') 
        # Hackity, just being used to get current user's test option for now
        if answerer.enrolled_in_experiment? "reengagement interval"
          strategy = Post.create_split_test(answerer.id, "reengagement interval", "3/7/10", "2/5/7", "5/7/7") 
        end
        in_reply_to = "reengage inactive"
      end

      # Check if in response to incorrect answer follow-up
      unless in_reply_to
        last_followup = Post.where("intention = ? and in_reply_to_user_id = ? and publication_id = ?", 'incorrect answer follow up', answerer.id, publication.id).order("created_at DESC").limit(1).first
        if last_followup.present? and Post.joins(:conversation).where("posts.id <> ? and posts.user_id = ? and posts.correct is not null and posts.created_at > ? and conversations.publication_id = ?", user_post.id,  answerer.id, last_followup.created_at, publication.id).blank?
          in_reply_to = "incorrect answer follow up" 
        end
      end

      # Check if in response to first question mention
      unless in_reply_to
        new_follower_mention = Post.where("intention = ? and in_reply_to_user_id = ? and publication_id = ?", 'new user question mention', answerer.id, publication.id).order("created_at DESC").limit(1).first
        if new_follower_mention.present? and Post.joins(:conversation).where("posts.id <> ? and posts.user_id = ? and posts.correct is not null and posts.created_at > ? and conversations.publication_id = ?", user_post.id, answerer.id, new_follower_mention.created_at, publication.id).present?
          in_reply_to = "new follower question mention"
        end
      end

      Post.trigger_split_test(answerer.id, 'wisr posts propagate to twitter') if answerer.posts.where("intention = ? and created_at < ?", 'twitter feed propagation experiment', 1.day.ago).present?

      # Fire mixpanel answer event
      Mixpanel.track_event "answered", {
        :distinct_id => answerer.id,
        :account => self.twi_screen_name,
        :type => "app",
        :in_reply_to => in_reply_to,
        :strategy => strategy
      }
    else
      parent_post = user_post.parent
      if parent_post.present?
        case parent_post.intention
        when 'reengage inactive'
          Post.trigger_split_test(answerer.id, 'reengage last week inactive') 
          if answerer.enrolled_in_experiment? "reengagement interval"
            strategy = Post.create_split_test(answerer.id, "reengagement interval", "3/7/10", "2/5/7", "5/7/7") 
          end
          in_reply_to = "reengage inactive"
        when 'incorrect answer follow up'
          in_reply_to = "incorrect answer follow up" 
        when 'new user question mention'
          in_reply_to = "new follower question mention"
        end
      end

      # Fire mixpanel answer event
      Mixpanel.track_event "answered", {
        :distinct_id => answerer.id,
        :time => user_post.created_at.to_i,
        :account => self.twi_screen_name,
        :type => "twitter",
        :in_reply_to => in_reply_to,
        :strategy => strategy,
        :autoresponse => (options[:autoresponse].present? ? options[:autoresponse] : false)
      }        
    end  
  end

  #here is an example of a function that cannot scale
  def self.leaderboard(id, data = {}, scores = [])
    posts = Post.select(:user_id).where(:in_reply_to_user_id => id, :correct => true).group_by(&:user_id).to_a.sort! {|a, b| b[1].length <=> a[1].length}[0..4]
    users = User.select([:twi_screen_name, :twi_profile_img_url, :id]).find(posts.collect {|post| post[0]}).group_by(&:id)
    posts.each { |post| scores << {:user => users[post[0]].first, :correct => post[1].length} }
    data[:scores] = scores
    return data
  end  

  def generate_response(correct)
    correct ? "#{CORRECT.sample} #{COMPLEMENT.sample}" : "#{INCORRECT.sample}"
  end

  def request_ugc user
    if !Question.exists?(:user_id => user.id) and !Post.exists?(:in_reply_to_user_id => user.id, :intention => 'solicit ugc') and user.posts.where("correct = ? and in_reply_to_user_id = ?", true, self.id).size > 9
      puts "attempting to send ugc request to #{user.twi_screen_name} on handle #{self.twi_screen_name}"
      script = self.get_ugc_script(user)
      if Post.create_split_test(user.id, 'ugc request type', 'mention', 'dm') == 'dm'
        Post.dm(self, user, script, {
          :intention => "solicit ugc"
        })
      else
        Post.tweet(self, script, {
          :reply_to => user.twi_screen_name,
          :in_reply_to_user_id => user.id,
          :intention => 'solicit ugc',
          :interaction_type => 2
        })
      end
    end
  end

  def get_ugc_script user
    script = Post.create_split_test(user.id, "ugc script", 
      "You know this material pretty well, how about writing a question or two? DM one to me or enter it at wisr.com/feeds/{asker_id}?q=1", 
      "You're pretty good at this stuff, try writing a question for others to answer! DM me or enter it at wisr.com/feeds/{asker_id}?q=1", 
      "Want to post your own question on {asker_name}? DM me one or input it at wisr.com/feeds/{asker_id}?q=1", 
      "Would you be interested in contributing some questions of your own? If so, DM me or enter them here: wisr.com/feeds/{asker_id}?q=1", 
      "You're a pro! Want to write some of your own questions? DM them to me or enter them at wisr.com/feeds/{asker_id}?q=1"
    )
    script = script.gsub "{asker_id}", self.id.to_s
    script = script.gsub "{asker_name}", self.twi_screen_name
    return script
  end

  def self.send_weekly_progress_dms
    recipients = Asker.select_progress_report_recipients()
    Asker.send_progress_report_dms(recipients)
  end

  def self.select_progress_report_recipients
    User.includes(:posts).not_asker_not_us.where("posts.correct is not null and posts.created_at > ?", 1.week.ago).reject { |user| user.posts.size < 3 }
  end

  def self.send_progress_report_dms recipients, asker_followers = {}
    asker_hash = Asker.all.group_by(&:id)
    recipients.each do |recipient|
      asker, text = Asker.compose_progress_report(recipient, asker_hash)
      
      if asker_followers[asker.id].blank?
        asker_followers[asker.id] = Post.twitter_request { asker.twitter.follower_ids().ids } 
      end
      
      if asker_followers[asker.id].include?(recipient.twi_user_id) and Post.create_split_test(recipient.id, "weekly progress report", "false", "true") == "true"
        Post.dm(asker, recipient, text, {:intention => "progress report"})
        sleep 1
      end
    end
  end

  def self.compose_progress_report recipient, asker_hash, script = "Last week:"
    primary_asker = asker_hash[recipient.posts.collect(&:in_reply_to_user_id).group_by { |e| e }.values.max_by(&:size).first].first
    activity_hash = User.get_activity_summary(recipient)

    ugc_answered_count = recipient.get_my_questions_answered_this_week_count

    activity_hash.each_with_index do |(asker_id, activity), i|
      if i < 3 # Only include top 3 askers
        next if i > 0 and ugc_answered_count > 0
        script += "," if (i > 0 and activity_hash.size > 2)
        script += " and" if (((i + 1) == activity_hash.size or i == 2) and i != 0)
        script += " #{activity[:count]}"
        script += " #{(activity[:count] > 1 ? "questions" : "question")} answered" if i == 0
        script += " on #{asker_hash[asker_id][0].twi_screen_name}"
        script += " (#{activity[:lifetime_total]} all time)" if activity[:lifetime_total] > 9 and script.size < 125
      end
    end

    script += "."

    if ugc_answered_count > 0
      script += " Questions that you wrote were answered "
      script += ugc_answered_count > 1 ? "#{ugc_answered_count} times!" : "once!"
    else
      complement = PROGRESS_COMPLEMENTS.sample
      script += " #{complement}" if (script.size + complement.size + 1) < 140
    end

    return primary_asker, script
  end


  def self.export_stats_to_csv askers = nil, domain = 9999

    askers = Asker.all unless askers

    _user_ids_by_day = Post.social.not_us.not_spam\
      .where("in_reply_to_user_id IN (?)", askers.collect(&:id))\
      .where("created_at > ?", Date.today - (domain + 31).days)\
      .select(["to_char(posts.created_at, 'YY/MM/DD') as created_at", "array_to_string(array_agg(user_id),',') AS user_ids"]).group("to_char(posts.created_at, 'YY/MM/DD')").all\
      .map{|p| {:created_at => p.created_at, :user_ids => p.user_ids.split(",")}}
    user_ids_by_day = _user_ids_by_day  
      .group_by{|p| p[:created_at]}\
      .each{|k,r| r.replace r.first[:user_ids].uniq }\

    _user_ids_by_week = _user_ids_by_day.group_by{|p| p[:created_at].beginning_of_week}
    user_ids_by_week = {}
    _user_ids_by_week.each{|date, ids_wrapped_in_posts| user_ids_by_week[date] = ids_wrapped_in_posts.map{|ids_wrapped_in_post|ids_wrapped_in_post[:user_ids]}.flatten.uniq}
    user_ids_by_week

    data = []
    user_ids_by_week.each do |date, user_ids|
      row = [date.strftime("%m/%d/%y")]
      row += [user_ids_by_day.reject{|ddate, user_ids| ddate > date + 6.days}.values.flatten.uniq.count]
      row += [user_ids_by_day.reject{|ddate, user_ids| ddate > date + 6.days || ddate < date - 24.days}.values.flatten.uniq.count]
      row += [user_ids.count]
      row += [(user_ids_by_day.reject{|ddate, user_ids| ddate > date + 6.days || ddate < date }.values.flatten.count.to_f / 7.0).round]
      data << row
    end
    data = [['Date', 'Us', 'MAUs', 'WAUs', 'DAUs']] + data
    #data.pop
    require 'csv'
    CSV.open("tmp/exports/asker_stats_#{askers.collect(&:id).join('-').hash}.csv", "wb") do |csv|
      data.transpose.each do |row|
        csv << row
      end
    end
  end
end