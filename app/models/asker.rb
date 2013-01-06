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
  	twi_follower_ids = self.twitter.follower_ids.ids
  	wisr_follower_ids = self.followers.collect(&:twi_user_id)

  	# Add new followers in wisr
  	(twi_follower_ids - wisr_follower_ids).each { |new_user_twi_id| self.followers << User.find_or_create_by_twi_user_id(new_user_twi_id) }

		# Remove unfollowers from asker follow association  	
  	unfollowed_users = User.where("twi_user_id in (?)", (wisr_follower_ids - twi_follower_ids))
  	unfollowed_users.each { |unfollowed_user| self.followers.delete(unfollowed_user) }
  	
  	return twi_follower_ids
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
      .where("users.last_interaction_at < ? and users.last_interaction_at > ?", begin_range, end_range)\
      .where("posts.created_at > ? and posts.correct is not null", end_range)

    # Get recently sent re-engagements
    recent_reengagements = Post.where("in_reply_to_user_id in (?)", disengaging_users.collect(&:id))\
      .where("intention = 'reengage inactive'")\
      .where("created_at > ?", end_range)
    return disengaging_users, recent_reengagements
  end

  def self.compile_recipients_by_asker(strategy, disengaging_users, recent_reengagements, asker_recipients = {})
    disengaging_users.each do |user|
      test_option = Post.create_split_test(user.id, "reengagement interval", "3/7/10", "2/5/7", "5/7/7")
      strategy = test_option.split("/").map { |e| e.to_i }
      last_answer_at = user.posts.sort_by { |p| p.created_at }.last.created_at
      user_reengagments = recent_reengagements.select { |p| p.in_reply_to_user_id == user.id and p.created_at > last_answer_at }.sort_by(&:created_at)
      next_checkpoint = strategy[user_reengagments.size]
      next if next_checkpoint.blank?
      if user_reengagments.blank? or ((Time.now - user_reengagments.last.created_at) > next_checkpoint.days)
        sample_asker_id = user.posts.sample.in_reply_to_user_id
        asker_recipients[sample_asker_id] ||= {:recipients => []}
        asker_recipients[sample_asker_id][:recipients] << {:user => user, :interval => strategy[user_reengagments.size], :strategy => test_option}
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
        puts "sending reengagement to #{user.twi_screen_name} (interval = #{user_hash[:interval]})"
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
          :intention => "reengage inactive"
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
    new_user_questions = Question.find(askers.collect(&:new_user_q_id)).group_by(&:created_for_asker_id)
    askers.each do |asker|
      stop = false
      new_followers = Post.twitter_request { asker.twitter.follower_ids.ids.first(50) } || []
      new_followers.each do |tid|
        break if stop
        follow_response = Post.twitter_request { asker.twitter.follow(tid) }
        stop = true if follow_response.blank?
        sleep(1)
        user = User.find_or_create_by_twi_user_id(tid)
        next if new_user_questions[asker.id].blank? or asker.posts.where(:provider => 'twitter', :interaction_type => 4, :in_reply_to_user_id => user.id).count > 0
        Post.dm(asker, user, "Here's your first question! #{new_user_questions[asker.id][0].text}", {:intention => "initial question dm"})
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
          if popular_post = asker.posts.includes(:conversations).where("created_at > ? and interaction_type = 1", 1.week.ago).sort_by {|p| p.conversations.size}.last
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

  def update_aggregate_activity_cache correct
    current_cache = (Rails.cache.read("aggregate activity") ? Rails.cache.read("aggregate activity").dup : {})
    current_cache[current_user.id] ||= {:askers => {}}
    current_cache[current_user.id][:twi_screen_name] = current_user.twi_screen_name
    current_cache[current_user.id][:askers][self.id] ||= Hash.new(0)
    current_cache[current_user.id][:askers][self.id][:last_answer_at] = Time.now
    current_cache[current_user.id][:askers][self.id][:count] += 1
    current_cache[current_user.id][:askers][self.id][:correct] += 1 if correct
    Rails.cache.write("aggregate activity", current_cache)
  end

  def app_response answerer, conversation, user_post, answer, publication, post_aggregate_activity
    # NECESSARY?
    # user_post.update_responded(answer.correct, publication_id, publication.question_id, asker_id)

    response_text = post.generate_response(status)
    publication.question.resource_url ? resource_url = "#{URL}/posts/#{post.id}/refer" : resource_url = "#{URL}/questions/#{publication.question_id}/#{publication.question.slug}"
    if answer.correct == false and Post.create_split_test(current_user.id, "include answer in response", "false", "true") == "true"
      correct_answer = Answer.where("question_id = ? and correct = ?", answer.question_id, true).first()
      response_text = "#{['Sorry', 'Nope', 'No'].sample}, I was looking for '#{correct_answer.text}'"
      resource_url = nil
    end
    
    if post_aggregate_activity
      if resource_url and answer.correct == false
        short_resource_url = Post.shorten_url(
          resource_url, 
          'wisr', 
          'res', 
          answerer.twi_screen_name, 
          publication.question.resource_url ? false : true
        )
        response_text += " Find the answer at #{short_resource_url}" if short_resource_url.present?
      end
      app_post = Post.create({
        :user_id => self.id,
        :provider => 'wisr',
        :text => response_text,
        :in_reply_to_post_id => user_post.id,
        :in_reply_to_user_id => answerer.id,
        :conversation_id => conversation.id,
        :url => answer.correct ? short_resource_url : nil,
        :posted_via_app => true, 
        :requires_action => false,
        :interaction_type => 2,
        :intention => 'grade'
      })
    else
      app_post = Post.tweet(asker, response_text, {
        :reply_to => answerer.twi_screen_name,
        :long_url => "#{URL}/feeds/#{asker.id}/#{publication_id}", 
        :interaction_type => 2, 
        :link_type => status[0..2], 
        :conversation_id => conversation.id, 
        :in_reply_to_post_id => (user_post ? user_post.id : nil), 
        :in_reply_to_user_id => answerer.id,
        :link_to_parent => true, 
        :resource_url => answer.correct ? nil : resource_url,
        :wisr_question => publication.question.resource_url ? false : true,
        :intention => 'grade'
      })        
    end

    # Check if we should ask for UGC
    User.request_ugc(answerer, asker)

    # GROSS, CLEAN THESE UP

    # Check if in response to re-engage message
    in_reply_to = nil
    strategy = nil
    last_inactive_reengagement = Post.where("intention = ? and in_reply_to_user_id = ? and publication_id = ?", 'reengage inactive', answerer.id, publication_id).order("created_at DESC").limit(1).first
    if last_inactive_reengagement.present? and Post.joins(:conversation).where("posts.id <> ? and posts.user_id = ? and posts.correct is not null and posts.created_at > ? and conversations.publication_id = ?", user_post.id, answerer.id, last_inactive_reengagement.created_at, publication_id).blank?
      Post.trigger_split_test(current_user.id, 'reengage last week inactive') 
      # Hackity, just being used to get current user's test option for now
      if current_user.enrolled_in_experiment? "reengagement interval"
        strategy = Post.create_split_test(user.id, "reengagement interval", "3/7/10", "2/5/7", "5/7/7") 
      end
      in_reply_to = "reengage inactive"
    end

    # Check if in response to incorrect answer follow-up
    unless in_reply_to
      last_followup = Post.where("intention = ? and in_reply_to_user_id = ? and publication_id = ?", 'incorrect answer follow up', answerer.id, publication_id).order("created_at DESC").limit(1).first
      if last_followup.present? and Post.joins(:conversation).where("posts.id <> ? and posts.user_id = ? and posts.correct is not null and posts.created_at > ? and conversations.publication_id = ?", user_post.id,  answerer.id, last_followup.created_at, publication_id).blank?
        Post.trigger_split_test(current_user.id, 'include answer in response')
        in_reply_to = "incorrect answer follow up" 
      end
    end

    # Check if in response to first question mention
    unless in_reply_to
      new_follower_mention = Post.where("intention = ? and in_reply_to_user_id = ? and publication_id = ?", 'new user question mention', answerer.id, publication_id).order("created_at DESC").limit(1).first
      if new_follower_mention.present? and Post.joins(:conversation).where("posts.id <> ? and posts.user_id = ? and posts.correct is not null and posts.created_at > ? and conversations.publication_id = ?", user_post.id,  'new user question mention', answerer.id, new_follower_mention.created_at, publication_id).present?
        in_reply_to = "new follower question mention"
      end
    end

    Post.trigger_split_test(answerer.id, 'wisr posts propagate to twitter') if answerer.posts.where("intention = ? and created_at < ?", 'twitter feed propagation experiment', 1.day.ago).present?

    # Fire mixpanel answer event
    Mixpanel.track_event "answered", {
      :distinct_id => answerer.id,
      :account => asker.twi_screen_name,
      :type => "app",
      :in_reply_to => in_reply_to,
      :strategy => strategy
    }
  end    

  def self.grade_post()
    pub = Publication.find(params[:publication_id].to_i)
    # pub.question.resource_url ? resource_url = "#{URL}/posts/#{post.id}/refer" : resource_url = "#{URL}/questions/#{publication.question_id}/#{publication.question.slug}"

    post = pub.posts.where(:provider => "twitter").first
    user_post.update_responded(correct, params[:publication_id].to_i, pub.question_id, params[:asker_id])
    user_post.update_attribute(:correct, correct)
    long_url = (params[:publication_id].nil? ? nil : "#{URL}/feeds/#{params[:asker_id]}/#{params[:publication_id]}")
    if correct.nil? or correct
      resource_url = nil
      wisr_question = false
    else
      if pub.question.resource_url.nil?
        resource_url = "#{URL}/questions/#{pub.question_id}/#{pub.question.slug}"
        wisr_question = true
      else
        resource_url = "#{URL}/posts/#{post.id}/refer"
        wisr_question = false
      end
    end         

    if params[:correct] == "false" and Post.create_split_test(params[:in_reply_to_user_id], "include answer in response", "false", "true") == "true"
      correct_answer = pub.question.answers.where(:correct => true).first()
      response_text = "#{['Sorry', 'Nope', 'No'].sample}, I was looking for '#{correct_answer.text}'"
      resource_url = nil
      wisr_question = nil
    end

    response_post = Post.tweet(asker, response_text, {
      :reply_to => params[:username], 
      :long_url => long_url, 
      :interaction_type => 2, 
      :conversation_id => conversation.id,
      :in_reply_to_post_id => params[:in_reply_to_post_id], 
      :in_reply_to_user_id => params[:in_reply_to_user_id], 
      :link_to_parent => false,
      :resource_url => resource_url,
      :wisr_question => wisr_question,
      :intention => 'grade'
    })
    user = user_post.user
    user.update_user_interactions({
      :learner_level => (correct.present? ? "twitter answer" : "mention"), 
      :last_interaction_at => user_post.created_at,
      :last_answer_at => (correct.present? ? user_post.created_at : nil)
    })

    # Check if we should ask for UGC
    User.request_ugc(user, asker)

    # Analytics + A/B tests
    parent_post = user_post.parent
    in_reply_to = nil
    strategy = nil
    if parent_post.present?
      case parent_post.intention
      when 'reengage inactive'
        Post.trigger_split_test(params[:in_reply_to_user_id], 'reengage last week inactive') 
        # Post.trigger_split_test(params[:in_reply_to_user_id], "reengagement interval")
        if user.enrolled_in_experiment? "reengagement interval"
          strategy = Post.create_split_test(user.id, "reengagement interval", "3/7/10", "2/5/7", "5/7/7") 
        end
        in_reply_to = "reengage inactive"
      when 'incorrect answer follow up'
        Post.trigger_split_test(params[:in_reply_to_user_id], 'include answer in response')
        in_reply_to = "incorrect answer follow up" 
      when 'new user question mention'
        in_reply_to = "new follower question mention"
      end
    end

    # Fire mixpanel answer event
    Mixpanel.track_event "answered", {
      :distinct_id => params[:in_reply_to_user_id],
      :time => user_post.created_at.to_i,
      :account => asker.twi_screen_name,
      :type => "twitter",
      :in_reply_to => in_reply_to
    }    
  end
   
  #here is an example of a function that cannot scale
  def self.leaderboard(id, data = {}, scores = [])
    posts = Post.select(:user_id).where(:in_reply_to_user_id => id, :correct => true).group_by(&:user_id).to_a.sort! {|a, b| b[1].length <=> a[1].length}[0..4]
    users = User.select([:twi_screen_name, :twi_profile_img_url, :id]).find(posts.collect {|post| post[0]}).group_by(&:id)
    posts.each { |post| scores << {:user => users[post[0]].first, :correct => post[1].length} }
    data[:scores] = scores
    return data
  end  

  def self.get_ugc_script(asker, user)
    script = Post.create_split_test(user.id, "ugc script", 
      "You know this material pretty well, how about writing a question or two? DM one to me or enter it at wisr.com/feeds/{asker_id}?q=1", 
      "You're pretty good at this stuff, try writing a question for others to answer! DM me or enter it at wisr.com/feeds/{asker_id}?q=1", 
      "Want to post your own question on {asker_name}? DM me one or input it at wisr.com/feeds/{asker_id}?q=1", 
      "Would you be interested in contributing some questions of your own? If so, DM me or enter them here: wisr.com/feeds/{asker_id}?q=1", 
      "You're a pro! Want to write some of your own questions? DM them to me or enter them at wisr.com/feeds/{asker_id}?q=1"
    )
    script = script.gsub "{asker_id}", asker.id.to_s
    script = script.gsub "{asker_name}", asker.twi_screen_name
    return script
  end 
end