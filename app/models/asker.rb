class Asker < User
  belongs_to :client
  has_many :questions, :foreign_key => :created_for_asker_id
  has_one :new_user_question, :foreign_key => :new_user_q_id, :class_name => 'Question'

  belongs_to :new_user_question, :class_name => 'Question', :foreign_key => :new_user_q_id

  default_scope where(:role => 'asker')

  scope :published, where("published = ?", true)

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
    twi_follower_ids = Post.twitter_request { twitter.follower_ids.ids }

    if twi_follower_ids
      wisr_follower_ids = followers.collect(&:twi_user_id)

      # Add new followers in wisr
      (twi_follower_ids - wisr_follower_ids).each { |new_user_twi_id| 
        Post.twitter_request { twitter.follow(new_user_twi_id) }
        add_follower(User.find_or_create_by_twi_user_id(new_user_twi_id)) 
      }

      # Remove unfollowers from asker follow association    
      unfollowed_users = User.where("twi_user_id in (?)", (wisr_follower_ids - twi_follower_ids))
      unfollowed_users.each { |unfollowed_user| remove_follower(unfollowed_user) }
    else
      twi_follower_ids = followers.collect(&:id)
    end
    
    return twi_follower_ids 
  end 

  def add_follower user
    unless followers.include? user
      followers << user 
      send_new_user_question(user)
      user.segment
    end
  end

  def remove_follower user
    followers.delete(user)
    user.follows.delete(self)
    user.segment
  end

  def send_new_user_question user, dm_text = "Here's your first question! "
    return if posts.where("intention = 'initial question dm' and in_reply_to_user_id = ?", user.id).size > 0 or new_user_question.blank?
    
    if Post.create_split_test(user.id, "New user DM question == most popular question (=> regular)", "false", "true") == "true"
      question = most_popular_question :character_limit => (140 - dm_text.size)
    else
      question = new_user_question
    end

    dm_text += question.text
    answers = " (#{question.answers.shuffle.collect {|a| a.text}.join('; ')})" 
    dm_text += answers if (INCLUDE_ANSWERS.include?(id) and ((dm_text + answers).size < 141) and !question.text.include?("T/F") and !question.text.include?("T:F"))

    Post.dm(self, user, dm_text, {:question_id => question.id, :intention => "initial question dm"})
    Mixpanel.track_event "DM question to new follower", {
      :distinct_id => user.id,
      :account => twi_screen_name
    }
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

  # def self.reengage_inactive_users
  #   User.not_asker.includes(:posts).where('posts.intention' => 'reengage inactive')


  def self.reengage_inactive_users
    user_ids_to_last_active_at = Hash[*Post.not_spam.not_us\
      .select(["user_id", "max(created_at) as last_active_at"])\
      .group("user_id").map{|p| [p.user_id, Time.parse(p.last_active_at)]}.flatten]

    user_ids_to_last_reengaged_at = Hash[*Post.not_spam\
      .where('posts.intention' => 'reengage inactive')\
      .select(["in_reply_to_user_id", "max(created_at) as last_reengaged_at"])\
      .group("in_reply_to_user_id").map{|p| [p.in_reply_to_user_id, Time.parse(p.last_reengaged_at)]}.flatten]

    results = {reengage: 0, already_reengaged: 0, last_reengage: 0, last_reengage_already_sent: 0}
    # {:reengage=>1645, :already_reengaged=>706, :last_reengage=>4240, :last_reengage_already_sent=>987}

    user_ids_to_last_active_at.each do |user_id, last_active_at|
      strategy_str = Post.create_split_test(user_id, "reengagement intervals (age > 15 days)", "1/2/4/8", "1/2/4/8/15", "1/2/4/8/15/30")
      strategy = strategy_str.split("/").map { |e| e.to_i }

      last_reengaged_at = user_ids_to_last_reengaged_at[user_id] || Time.now - 1000.years
      # last_active_at_to_present_in_days = (Time.now - last_active_at)/60/60/24
      
      #find ideal time when user reengaged last/next
      aggregate_intervals = 0
      ideal_last_reengage_at = ideal_next_reengage_at = nil
      strategy.each_with_index do |int, i|
        if last_active_at + (aggregate_intervals + int).days < Time.now 
          aggregate_intervals += int 
          ideal_last_reengage_at = last_active_at + aggregate_intervals.days
        elsif last_active_at + (aggregate_intervals + int).days > Time.now 
          ideal_next_reengage_at = last_active_at + aggregate_intervals.days
          break
        end
      end

      if ideal_last_reengage_at and ideal_next_reengage_at and last_reengaged_at < ideal_last_reengage_at
        results[:reengage] += 1
      elsif ideal_last_reengage_at and ideal_next_reengage_at and last_reengaged_at >= ideal_last_reengage_at
        results[:already_reengaged] += 1
      elsif ideal_last_reengage_at and ideal_next_reengage_at.nil? and last_reengaged_at < ideal_last_reengage_at
        results[:last_reengage] += 1
      else
        results[:last_reengage_already_sent] += 1
      end

      # send_reengagement_tweets(user_id) if last_active_at + last_active_at_to_next_reengagement > Time.now

      # last_active_at_to_next_reengagement = strategy[0, reengagements_since_active_count + 1].sum
      # reengagements_since_active_count = Post.where(in_reply_to_user_id: user_id)\
      #   .where(intention: 'reengage inactive').where('created_at > ?', last_active_at).count
    end
    puts results
  end

  def self.send_reengagement_tweets(user_id)
    puts "reengage #{user_id}"
  end
  #   count = 0

  #   asker_recipients.each do |asker_id, recipient_data|
  #     asker = Asker.find(asker_id)
  #     follower_ids = asker.update_followers()
  #     publication = recipient_data[:publication]
  #     next unless asker and publication
  #     question = publication.question
  #     recipient_data[:recipients].each do |user_hash|
  #       user = user_hash[:user]
  #       next unless follower_ids.include? user.twi_user_id
  #       if Post.create_split_test(user.id, "Just question in reengagement tweet (answers)", "false", "true") == "false"
  #         option_text = Post.create_split_test(user.id, "reengage last week inactive", "Pop quiz:", "A question for you:", "Do you know the answer?", "Quick quiz:", "We've missed you!")
  #         text = "#{option_text} #{question.text}"
  #       else
  #         text = question.text
  #       end
  #       count += 1
  #       next

  #       puts "temp: send reengage inactive #{count}"
  #       Post.tweet(asker, text, {
  #         :reply_to => user.twi_screen_name,
  #         :long_url => "http://wisr.com/feeds/#{asker.id}/#{publication.id}",
  #         :in_reply_to_user_id => user.id,
  #         :posted_via_app => true,
  #         :publication_id => publication.id,  
  #         :requires_action => false,
  #         :interaction_type => 2,
  #         :link_to_parent => false,
  #         :link_type => "reengage",
  #         :intention => "reengage inactive",
  #         :include_answers => true,
  #         :question_id => question.id
  #       })
  #       Mixpanel.track_event "reengage inactive", {:distinct_id => user.id, :interval => user_hash[:interval], :strategy => user_hash[:strategy]}
  #       sleep(1)
  #     end
  #   end
  #   puts count
  # end

  def self.engage_new_users
    # Send DMs to new users
    # Asker.dm_new_followers
    Asker.all.each { |asker| asker.update_followers() }

    # Send mentions to new users
    Asker.mention_new_users
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
          :link_to_parent => false,
          :question_id => publication.question.id    
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
    
    recent_posts = Post.where("user_id is not null and ((correct = ? and created_at > ? and created_at < ? and interaction_type = 2) or ((intention = ? or intention = ?) and created_at > ?))", false, range_begin, range_end, 'reengage', 'incorrect answer follow up', range_end).includes(:user)
    user_grouped_posts = recent_posts.group_by(&:user_id)
    asker_ids = askers.collect(&:id)
    user_grouped_posts.each do |user_id, posts|
      # should ensure only one tweet per user as well here?
      next if asker_ids.include? user_id or recent_posts.where("(intention = ? or intention = ?) and in_reply_to_user_id = ?", 'reengage', 'incorrect answer follow up', user_id).present?
      incorrect_post = posts.sample
      publication = incorrect_post.conversation.publication
      question = publication.question
      asker = User.askers.find(incorrect_post.in_reply_to_user_id)
      Post.tweet(asker, "Try this one again: #{question.text}", {
        :reply_to => incorrect_post.user.twi_screen_name,
        :long_url => "http://wisr.com/questions/#{question.id}/#{question.slug}",
        # :in_reply_to_post_id => incorrect_post.id,
        :in_reply_to_user_id => user_id,
        # :conversation_id => incorrect_post.conversation_id,
        :publication_id => publication.id,
        :posted_via_app => true, 
        :requires_action => false,
        :interaction_type => 2,
        :link_to_parent => false,
        :link_type => "follow_up",
        :intention => "incorrect answer follow up",
        :include_answers => true,
        :question_id => question.id
      })  
      Mixpanel.track_event "incorrect answer follow up sent", {:distinct_id => user_id}
      sleep(1)
    end
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
    question = user_post.link_to_question
    resource_url = nil

    if options[:response_text].present?
      response_text = options[:response_text]
    elsif options[:tell]
      response_text = generate_response(correct, question, true)
    elsif options[:manager_response] or options[:autoresponse]
      response_text, resource_url = format_manager_response(user_post, correct, answerer, publication, question, options)
    else
      response_text = generate_response(correct, question)
    end

    if options[:post_to_twitter]
      app_post = Post.tweet(self, response_text, {
        :reply_to => answerer.twi_screen_name,
        :long_url => "#{URL}/feeds/#{id}/#{publication.id}", 
        :interaction_type => 2, 
        :link_type => correct ? "cor" : "inc", 
        :link_to_parent => options[:link_to_parent], 
        :in_reply_to_post_id => user_post.id, 
        :in_reply_to_user_id => answerer.id,
        :resource_url => resource_url,
        :wisr_question => publication.question.resource_url ? false : true,
        :intention => 'grade',
        :conversation_id => options[:conversation_id]
      })        
    else
      app_post = Post.create({
        :user_id => id,
        :provider => 'wisr',
        :text => response_text,
        :in_reply_to_post_id => user_post.id,
        :in_reply_to_user_id => answerer.id,
        :posted_via_app => true, 
        :requires_action => false,
        :interaction_type => 2,
        :intention => 'grade',
        :conversation_id => options[:conversation_id]
      })
      update_aggregate_activity_cache(answerer, correct)
    end

    # Mark user's post as responded to
    user_post.update_attributes(:requires_action => false, :correct => correct) unless user_post.posted_via_app

    # Trigger after answer actions
    after_answer_filter(answerer, user_post, {:learner_level => user_post.posted_via_app ? "feed answer" : "twitter answer"})

    # Trigger split tests, MP events
    update_metrics(answerer, user_post, publication, {:autoresponse => options[:autoresponse]})

    app_post
  end

  def format_manager_response user_post, correct, answerer, publication, question, options = {} # augment manager responses with links, RTs, hints
    response_text = ""
    resource_url = nil
    # split test hints for questions with hints that aren't posted through the app
    if question = user_post.in_reply_to_question and question.hint.present? and !user_post.posted_via_app
      test_name = "Hint when incorrect (answers question correctly later)"
      if correct # attempt to trigger
        previous_answers = question.in_reply_to_posts\
          .where('posts.user_id = ?', answerer.id)\
          .where('posts.created_at < ?', user_post.created_at)
        if previous_answers.present?
          Post.trigger_split_test(answerer.id, test_name)
        end
      else 
        if Post.create_split_test(answerer.id, test_name, 'false', 'true') == 'true'
          response_text = "#{INCORRECT.sample} Hint: #{question.hint}"
        end
      end
    end 

    if response_text.blank?  
      response_text = generate_response(correct, question)
      if correct and options[:quote_user_answer]
        cleaned_user_post = user_post.text.gsub /@[A-Za-z0-9_]* /, ""
        cleaned_user_post = "#{cleaned_user_post[0..47]}..." if cleaned_user_post.size > 50
        response_text += " RT '#{cleaned_user_post}'" 
      elsif !correct
        resource_url = publication.question.resource_url if publication.question.resource_url
      end
    end

    [response_text, resource_url]
  end

  def generate_response(correct, question, tell = false)
    response_text = ''
    if correct 
      response_text = "#{CORRECT.sample} #{COMPLEMENT.sample}"
    else
      if question
        response_text = ''
        response_text = "#{['Sorry', 'Not quite', 'No'].sample}, " unless tell
        answer_text = Answer.where("question_id = ? and correct = ?", question.id, true).first().text
        answer_text = "#{answer_text[0..77]}..." if answer_text.size > 80
        response_text +=  "I was looking for '#{answer_text}'"
      else
        response_text = INCORRECT.sample
      end
    end
    response_text
  end


  def auto_respond user_post
    return unless user_post.autocorrect.present? and user_post.requires_action

    answerer = user_post.user
    if user_post.is_dm?
      return unless (question = user_post.in_reply_to_question) == new_user_question
      return unless [1, 2].sample == 1 # only autograde half of eligible DMs
      interval = Post.create_split_test(answerer.id, "DM autoresponse interval (activity segment +)", "0", "30", "60", "120", "240")
      Delayed::Job.enqueue(
        TwitterPrivateMessage.new(self, answerer, generate_response(user_post.autocorrect, user_post.question), {:in_reply_to_post_id => user_post.id, :intention => "dm autoresponse"}),
        :run_at => interval.to_i.minutes.from_now
      )
      user_post.update_attribute :correct, user_post.autocorrect
      learner_level = "dm answer"
    else
      # make sure >= 20 autocorrected posts are checked each day
      if Post.where("autocorrect IS NOT NULL AND (correct IS NOT NULL OR requires_action = ?)", true).where("created_at > ?", Time.now - 1.day).count >= 20     #Post.create_split_test(answerer.id, "auto respond", "true", "false") == "true"

        root_post = user_post.conversation.post
        asker_response = app_response(user_post, user_post.autocorrect, {
          :link_to_parent => false, 
          :autoresponse => true,
          :post_to_twitter => true,
          :quote_user_answer => root_post.is_question_post? ? true : false,
          :link_to_parent => root_post.is_question_post? ? false : true
        })
        conversation = user_post.conversation || Conversation.create(:publication_id => user_post.publication_id, :post_id => user_post.in_reply_to_post_id, :user_id => user_post.user_id)
        conversation.posts << user_post
        conversation.posts << asker_response
        learner_level = "twitter answer"
      end
    end
    after_answer_filter(answerer, user_post, :learner_level => learner_level)
  end

  def after_answer_filter answerer, user_post, options = {}
    answerer.update_user_interactions({
      :learner_level => options[:learner_level], 
      :last_interaction_at => user_post.created_at,
      :last_answer_at => user_post.created_at
    })
    request_ugc(answerer)
    nudge(answerer)
  end 


  def nudge answerer
    return unless client and nudge_type = client.nudge_types.automatic.active.sample and answerer.nudge_types.blank? and answerer.posts.answers.where(:correct => true, :in_reply_to_user_id => id).size > 2 and answerer.is_follower_of?(self)

    puts "in nudge:"
    puts self.twi_screen_name, client.to_json

    if client.id == 14699
      nudge_type = NudgeType.find_by_text(Post.create_split_test(answerer.id, "SATHabit copy (click-through) < 123 >", 
        "You're doing really well! I offer a much more comprehensive (free) course here: {link}",
        "Nice work so far! You can practice with customized questions at: {link}",
        "Want to see how you would score on the SAT? Check it out: {link}",
        "Hey, if you're interested, you can get a personalized SAT question of the day at {link}",
        "You've answered {x} questions, with just {25-x} more you could have gotten an SAT score! Get one here: {link}"
        # "Great work so far! If you're interested, I have a more rigorous SAT prep course:",
        # "Howdy, are you taking the SAT soon? I have a very helpful (free) course:",
        # "If you're taking the SAT soon, I have a course you might find helpful :) Check it out:"
      ))
      if nudge_type.text.include? "{x}"
        question_count = answerer.posts.answers.where(:in_reply_to_user_id => id).size
        nudge_type.text = nudge_type.text.gsub "{x}", question_count.to_s
        nudge_type.text = nudge_type.text.gsub "{25-x}", (25 - question_count).to_s
      end
      nudge_type.send_to(self, answerer)

    elsif client.id == 29210
      nudge_type = client.nudge_types.active.automatic.sample
      post = nudge_type.send_to(self, answerer)
      
      tag = Tag.find_or_create_by_name("tutor-solicit-test")
      tag.posts << post
    else
      nudge_type.send_to(self, answerer)
    end

    # elsif client.id == 23624
    #   nudge_type = NudgeType.find_by_text(Post.create_split_test(answerer.id, "InstaEDU copy (click-through) < ? >", 
    #     "If you're interested, we work with a Biology tutor website. Could this be helpful?", 
    #     "",
    #     "",
    #     ""
    #   ))      
    # end
  end


  ## Update metrics

  def update_metrics answerer, user_post, publication, options = {}
    in_reply_to = nil
    strategy = nil
    if user_post.posted_via_app
      # Check if in response to re-engage message
      last_inactive_reengagement = Post.where("intention = ? and in_reply_to_user_id = ? and publication_id = ?", 'reengage inactive', answerer.id, publication.id).order("created_at DESC").limit(1).first
      if last_inactive_reengagement.present? and Post.joins(:conversation).where("posts.id <> ? and posts.user_id = ? and posts.correct is not null and posts.created_at > ? and conversations.publication_id = ?", user_post.id, answerer.id, last_inactive_reengagement.created_at, publication.id).blank?
        Post.trigger_split_test(answerer.id, 'reengage last week inactive') 
        Post.trigger_split_test(answerer.id, 'Just question in reengagement tweet (answers)') 
        strategy = answerer.get_experiment_option("reengagement intervals (age > 15 days)") if answerer.enrolled_in_experiment?("reengagement intervals (age > 15 days)")
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
          Post.trigger_split_test(answerer.id, 'Just question in reengagement tweet (answers)') 
          strategy = answerer.get_experiment_option("reengagement intervals (age > 15 days)") if answerer.enrolled_in_experiment?("reengagement intervals (age > 15 days)")
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

    # Events/triggers where posted_via_app doesn't matter
    Post.trigger_split_test(answerer.id, "reengagement intervals (age > 15 days)") if  answerer.age_greater_than 15.days 
  end


  ## Solicit UGC

  def request_ugc user
    if !Question.exists?(:user_id => user.id) and !Post.exists?(:in_reply_to_user_id => user.id, :intention => 'solicit ugc') and user.posts.where("correct = ? and in_reply_to_user_id = ?", true, id).size > 9
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
    script = Post.create_split_test(user.id, "ugc script v2.0", 
      "You know this material pretty well, how about writing a question or two? DM one to me or enter it at wisr.com/feeds/{asker_id}?q=1", 
      "Great work so far! Would you write a question or two for others to answer? DM me or enter it at wisr.com/feeds/{asker_id}?q=1",
      "Spread the knowledge and write a question or two! DM me or enter it at wisr.com/feeds/{asker_id}?q=1",
      "I'd love to have you write a question or two for this handle... if you would, DM me or enter it at wisr.com/feeds/{asker_id}?q=1",
      "Hey, would you mind writing a question for me to post? Enter it at wisr.com/feeds/{asker_id}?q=1",
      "Hey, would you mind writing a question for me to post? DM me back if you have one!"
      # "You're pretty good at this stuff, try writing a question for others to answer! DM me or enter it at wisr.com/feeds/{asker_id}?q=1" # second best from v1.0
    )
    script = script.gsub "{asker_id}", self.id.to_s
    script = script.gsub "{asker_name}", self.twi_screen_name
    return script
  end


  ## Weekly progress reports

  def self.send_weekly_progress_dms
    recipients = Asker.select_progress_report_recipients()
    Asker.send_progress_report_dms(recipients)
  end

  def self.select_progress_report_recipients
    User.includes(:posts).not_asker_not_us.where("posts.correct is not null and posts.created_at > ? and posts.in_reply_to_user_id in (?)", 1.week.ago, Asker.ids).reject { |user| user.posts.size < 3 }
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


  def self.retweet_related
    ACCOUNT_DATA.each do |asker_id, asker_hash|
      asker = Asker.find(asker_id)
      next unless asker.published
      publication = Publication.where(:asker_id => asker_hash[:retweet].sample, :published => true).order('updated_at DESC').limit(5).sample
      next unless publication
      post = publication.posts.statuses.sample
      Post.twitter_request { asker.twitter.retweet(post.provider_post_id) }
      if Time.now.hour % 12 == 0
        Post.tweet(asker, "Want me to publish YOUR questions? Click the link: wisr.com/feeds/#{asker.id}?q=1", {
          :intention => 'solicit ugc',
          :interaction_type => 2
        })
      end        
    end
  end


  ## Author followup

  def self.send_author_followups
    Asker.dm_author_followups(Asker.compile_author_followup_recipients)
  end

  def self.compile_author_followup_recipients recipient_hash = {}
    recent_questions = Question.recently_published_ugc.group_by(&:user_id)
    recent_followups = Post.author_followup.where("in_reply_to_user_id in (?) and created_at > ?", recent_questions.keys, 1.week.ago).order("created_at DESC").group_by(&:in_reply_to_user_id)

    recent_questions.each do |user_id, questions|
      questions = questions.select { |q| q.created_at > recent_followups[user_id].first.created_at } if recent_followups[user_id].present?
      questions = questions.select { |q| (q.in_reply_to_posts.to_a.count {|p| p.correct != nil}) > 2 }
      question = questions.sort_by { |q| q.in_reply_to_posts.size }.last
      recipient_hash[user_id] = {:text => question.text, :asker_id => question.created_for_asker_id, :answered_count => question.in_reply_to_posts.size} if question
    end
    recipient_hash
  end

  def self.dm_author_followups recipient_hash
    recipient_hash.each do |user_id, question_data|
      asker = Asker.find(question_data[:asker_id])
      user = User.find(user_id)
      next unless asker.update_followers().include? user.twi_user_id
      if Post.create_split_test(user.id, "author question followup (return ugc submission)", "false", "true") == "true"
        script = "So far, #{question_data[:answered_count]} people have answered your question "
        script += ((question_data[:text].size + 2) > (140 - script.size)) ? "'#{question_data[:text][0..(140 - 6 - script.size)]}...'" : "'#{question_data[:text]}'"
        Post.dm(asker, user, script, {:intention => "author followup"})
        script = "#{PROGRESS_COMPLEMENTS.sample} Write another here: wisr.com/feeds/#{asker.id}?q=1 (or DM it to me)"
        Post.dm(asker, user, script, {:intention => "author followup"})
        Mixpanel.track_event "author followup sent", {:distinct_id => user_id}
      end
    end
  end

  def most_popular_question options = {}
    options.reverse_merge!(:since => 99.years.ago, :character_limit => 9999)
    Question.find(
      Post.joins(:in_reply_to_question)\
        .answers\
        .mentions\
        .where("posts.in_reply_to_user_id = ? and posts.created_at > ?", id, options[:since])\
        .where("length(questions.text) < ?", options[:character_limit])\
        .group("posts.in_reply_to_question_id")\
        .count\
        .max{|a,b| a[1] <=> b[1]}[0]
    )
  end


  ## Stat export

  def self.export_stats_to_csv askers = nil, domain = 9999

    askers = Asker.all unless askers

    _user_ids_by_day = Post.social.not_us.not_spam\
      .where("in_reply_to_user_id IN (?)", askers.collect(&:id))\
      .where("created_at > ?", Date.today - (domain + 31).days)\
      .select(["to_char(posts.created_at, 'YY/MM/DD') as created_at", "array_to_string(array_agg(user_id),',') AS user_ids"]).group("to_char(posts.created_at, 'YY/MM/DD')").all\
      .map{|p| {:created_at => p.created_at, :user_ids => p.user_ids.split(",")}}
    user_ids_by_day = _user_ids_by_day\
      .group_by{|p| p[:created_at]}\
      .each{|k,r| r.replace r.first[:user_ids].uniq }\

    _user_ids_by_week = _user_ids_by_day.group_by{|p| p[:created_at].end_of_week}
    user_ids_by_week = {}
    _user_ids_by_week.keys.sort_by{|k|k}.each{|date| user_ids_by_week[date] = _user_ids_by_week[date].map{|ids_wrapped_in_post|ids_wrapped_in_post[:user_ids]}.flatten.uniq}

    followers_count_by_week = Relationship.select(["to_char(relationships.created_at, 'YY/MM/DD') as created_at", "array_to_string(array_agg(follower_id),',') AS follower_ids"])\
      .where("followed_id IN (?)", askers.collect(&:id)).group("to_char(relationships.created_at, 'YY/MM/DD')")\
      .group_by{|p| p[:created_at].end_of_week}\
      .each{|k,r| r.replace r.map{|o| o.follower_ids}.join(',').split(',') }

    unfollowers = Transition.select(["to_char(transitions.created_at, 'YY/MM/DD') as created_at", "array_to_string(array_agg(user_id),',') AS user_ids"])\
      .where(:segment_type => 2, :to_segment => 7).group("to_char(transitions.created_at, 'YY/MM/DD')")\
      .group_by{|p| p[:created_at].end_of_week}\
      .each{|k,r| r.replace r.map{|o| o.user_ids}.join(',').split(',') }

    data = []
    user_ids_by_week.each do |date, user_ids|
      row = [date.strftime("%m/%d/%y")]
      row += [user_ids_by_day.reject{|ddate, user_ids| ddate > date}.values.flatten.uniq.count]
      row += [user_ids_by_day.reject{|ddate, user_ids| ddate > date || ddate < date - 30.days}.values.flatten.uniq.count]
      row += [user_ids.count]
      row += [(user_ids_by_day.reject{|ddate, user_ids| ddate > date || ddate < date - 6.days}.values.flatten.count.to_f / 7.0).round]
      row += [followers_count_by_week[date].to_a.count]
      row += [unfollowers[date].to_a.count]
      data << row
    end
    data = [['Date', 'Us', 'MAUs', 'WAUs', 'DAUs', "Followers", "Unfollowers"]] + data #Followers, Unfollowers
    require 'csv'
    CSV.open("tmp/exports/asker_stats_#{askers.collect(&:id).join('-').hash}.csv", "wb") do |csv|
      data.transpose.each do |row|
        csv << row
      end
    end
  end


  ## Unused?

  def self.leaderboard(id, data = {}, scores = [])
    posts = Post.select(:user_id).where(:in_reply_to_user_id => id, :correct => true).group_by(&:user_id).to_a.sort! {|a, b| b[1].length <=> a[1].length}[0..4]
    users = User.select([:twi_screen_name, :twi_profile_img_url, :id]).find(posts.collect {|post| post[0]}).group_by(&:id)
    posts.each { |post| scores << {:user => users[post[0]].first, :correct => post[1].length} }
    data[:scores] = scores
    return data
  end    
end