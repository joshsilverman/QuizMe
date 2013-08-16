class Asker < User
  include ManageTwitterRelationships
  include AuthorizationsHelper

  belongs_to :client
  has_many :questions, :foreign_key => :created_for_asker_id
  has_one :new_user_question, :foreign_key => :new_user_q_id, :class_name => 'Question'
  
  has_and_belongs_to_many :related_askers, -> { uniq }, class_name: 'Asker', join_table: :related_askers, foreign_key: :asker_id, association_foreign_key: :related_asker_id

  belongs_to :new_user_question, :class_name => 'Question', :foreign_key => :new_user_q_id

  default_scope -> { where(role: 'asker') }

  scope :published, -> { where("published = ?", true) }

  # cached queries

  def get_stats
    question_count, questions_answered, follower_count = Rails.cache.fetch "stats_by_asker_#{id}", :expires_in => 1.day, :race_condition_ttl => 15 do
      question_count = publications.select(:id).where(:published => true).size
      questions_answered = Post.where("in_reply_to_user_id = ? and correct is not null", id).count
      follower_count = followers.size
      [question_count, questions_answered, follower_count]
    end
    return [question_count, questions_answered, follower_count]
  end

  def self.by_twi_screen_name
    Rails.cache.fetch('askers_by_twi_screen_name', :expires_in => 5.minutes){Asker.order("twi_screen_name ASC").all}
  end

  def self.ids
    Rails.cache.fetch('asker_ids', :expires_in => 5.minutes){Asker.all.collect(&:id)}
  end

  def self.published_ids
    Rails.cache.fetch('published_asker_ids', :expires_in => 5.minutes){Asker.published.collect(&:id)}
  end

  def self.twi_screen_names
    Rails.cache.fetch('asker_twi_screen_names', :expires_in => 5.minutes){Asker.published.collect(&:twi_screen_name)}
  end

  def self.askers_with_id_and_twi_screen_name
    Rails.cache.fetch('asker_twi_screen_names', :expires_in => 1.hour){Asker.published.select([:twi_screen_name, :id])}
  end

  def self.in_progress_askers
    Rails.cache.fetch('in_progress_askers', :expires_in => 1.hour){ 
      Asker.includes(:questions)\
        .select('"users".*')\
        .where("users.published is null")\
        .select { |asker| asker.questions.size < 50 and asker.related_askers.size > 0 }
    }
  end

  def descriptions
    topics.descriptions
  end

  def hashtags
    topics.hashtags
  end

  def search_terms
    topics.search_terms
  end

  def categories
    topics.categories
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

  def send_public_message text, options = {}
    recipient = User.where(id: options[:in_reply_to_user_id]).first
    communication_preference = recipient.blank? ? 1 : recipient.communication_preference
    case communication_preference
    when 2
      self.becomes(EmailAsker).send_public_message(text, options, recipient)
    when 1
      self.becomes(TwitterAsker).send_public_message(text, options, recipient)
    else
      raise 'no public send method for that communication preference'
    end
  end
  
  def send_private_message recipient, text, options = {}
    self.becomes(TwitterAsker).send_private_message(recipient, text, options)
  end

  def publish_question
    queue = self.publication_queue
    unless queue.blank?
      publication = queue.publications.order("id ASC")[queue.index]
      PROVIDERS.each { |provider| Post.publish(provider, self, publication) }
      queue.increment_index(self.posts_per_day)
      # Rails.cache.delete("askers:#{self.id}:show")
    end
  end

  def send_new_user_question user, options = {}
    return if posts.where("intention = 'initial question dm' and in_reply_to_user_id = ?", user.id).size > 0
    dm_text = "Here's your first question! "
    question = most_popular_question :character_limit => (140 - dm_text.size), exclude_strings: ["the following"]

    dm_text += question.text
    answers = " (#{question.answers.shuffle.collect {|a| a.text}.join('; ')})" 
    dm_text += answers if (INCLUDE_ANSWERS.include?(id) and ((dm_text + answers).size < 141) and !question.text.include?("T/F") and !question.text.include?("T:F"))

    self.send_private_message(user, dm_text, {:question_id => question.id, :intention => "initial question dm"})
    Mixpanel.track_event "DM question to new follower", {
      :distinct_id => user.id,
      :account => twi_screen_name,
      :backlog => options[:backlog] == true ? true : false
    }
  end

  def send_backlog_new_user_dms limit = 1
    engaged_user_ids = posts.select(:in_reply_to_user_id).group(:in_reply_to_user_id)\
      .where("in_reply_to_user_id IS NOT NULL")\
      .collect(&:in_reply_to_user_id)
    backlog_users = followers.not_asker\
      .where('relationships.follower_id NOT IN (?)', engaged_user_ids).order("follower_id DESC").limit limit
    backlog_users.each do |u|
      send_new_user_question(u, { backlog: true })
    end
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
          asker.send_public_message(script, {
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

  def self.reengage_inactive_users options = {}
    start_time = Time.find_zone('UTC').parse('2013-03-25 9am')
    days_since_start_time = ((Time.now - start_time) / 1.day.to_i).to_i
    period = 20 + (days_since_start_time * 3)

    strategy = options[:strategy]
    strategy_string = options[:strategy].join "/" if strategy

    user_ids_to_last_active_at = Hash[*Post.not_spam.answers.social.not_us\
      .select(["user_id", "max(created_at) as last_active_at"])\
      .where("created_at > ?", period.days.ago)\
      .group("user_id").map{|p| [p.user_id, p.last_active_at.time]}.flatten]

    user_ids_to_last_reengaged_at = Hash[*Post.not_spam\
      .reengage_inactive\
      .where('posts.in_reply_to_user_id in (?)', user_ids_to_last_active_at.keys)\
      .select(["in_reply_to_user_id", "max(created_at) as last_reengaged_at"])\
      .group("in_reply_to_user_id").map{|p| [p.in_reply_to_user_id, p.last_reengaged_at.time]}.flatten]

    @scored_questions = Question.score_questions
    @question_sent_by_asker_counts = {}

    user_ids_to_last_active_at.each do |user_id, last_active_at|
      unless options[:strategy]
        strategy_string = Post.create_split_test(user_id, "reengagement intervals (age > 15 days)", "1/2/4/8", "1/2/4/8/15", "1/2/4/8/15/30")
        strategy = strategy_string.split("/").map { |e| e.to_i }
      end 

      last_reengaged_at = user_ids_to_last_reengaged_at[user_id] || 1000.years.ago
      
      aggregate_intervals = 0
      ideal_last_reengage_at = nil
      strategy.each do |interval|
        if (last_active_at + (aggregate_intervals + interval).days) < Time.now
          aggregate_intervals += interval
          ideal_last_reengage_at = last_active_at + aggregate_intervals.days
        else
          break
        end
      end

      is_backlog = ((last_active_at < (start_time - 20.days)) ? true : false)
      
      Asker.reengage_user(user_id, {strategy: strategy_string, interval: aggregate_intervals, is_backlog: is_backlog, last_active_at: last_active_at, type: options[:type]}) if (ideal_last_reengage_at and (last_reengaged_at < ideal_last_reengage_at))
    end
  end 

  def self.reengage_user user_id, options = {}
    user = User.find user_id
    return false unless (Asker.published_ids & user.follows.collect(&:id)).present? # make sure there are published askers to reengage from

    if options[:type].present? or Post.create_split_test(user.id, 'include solicitations as reengagements (=> advanced)', 'false', 'true') == 'true'
      asker, question, publication, text, long_url = nil, nil, nil, nil, nil
      reengagement_type = options[:type] || user.pick_reengagement_type(options[:last_active_at])
      case reengagement_type
      when :question
        asker, question = user.select_reengagement_asker_and_question(@scored_questions)
        return false unless asker and question
        text = question.text
        publication = question.publications.order("created_at DESC").first
        long_url = "http://wisr.com/feeds/#{asker.id}/#{publication.id}"
        intention = 'reengage inactive'
      when :moderation
        asker = user.asker_follows.sample
        text = I18n.t("reengagements.moderation").sample
        text.gsub! '<link>', asker.authenticated_link("#{URL}/moderations/manage", user, (Time.now + 1.week))
        intention = 'request mod'
      when :author
        asker = user.asker_follows.sample
        text = I18n.t("reengagements.author").sample
        text.gsub! '<link>', "#{URL}/feeds/#{asker.id}?q=1"
        intention = 'solicit ugc'
      end
    else
      reengagement_type = :question
      asker, question = user.select_reengagement_asker_and_question(@scored_questions)
      text = question.text
      publication = question.publications.order("created_at DESC").first
      long_url = "http://wisr.com/feeds/#{asker.id}/#{publication.id}"
    end

    return false unless asker and text

    @question_sent_by_asker_counts[asker.id] ||= 0
    return false unless @question_sent_by_asker_counts[asker.id] < 25 # limit number of reengagements sent to 25 per session
    @question_sent_by_asker_counts[asker.id] += 1

    # puts "send reengagement: '#{text}' to #{user.twi_screen_name}" 

    if reengagement_type == :question
      asker.send_public_message(text, {
        reply_to: user.twi_screen_name,
        long_url: long_url ? "http://wisr.com/feeds/#{asker.id}/#{publication.id}" : nil,
        in_reply_to_user_id: user.id,
        posted_via_app: true,
        requires_action: false,
        interaction_type: 2,
        link_to_parent: false,
        link_type: "reengage",
        intention: intention,
        include_answers: true,
        publication_id: (publication ? publication.id : nil),  
        question_id: (question ? question.id : nil),
        is_reengagement: true
      })
    else
      asker.send_private_message(user, text, {
        posted_via_app: true,
        requires_action: false,
        interaction_type: 4,
        link_type: "reengage",
        intention: intention,
        include_answers: true,
        is_reengagement: true
      })
    end

    Mixpanel.track_event "reengage inactive", {
      distinct_id: user.id, 
      interval: options[:interval], 
      strategy: options[:strategy], 
      backlog: options[:is_backlog],
      asker: asker.twi_screen_name,
      type: reengagement_type
    }

    sleep(1)
    
    return true
  end

  def self.engage_new_users
    # Send DMs to new users
    selector = (((Time.now - Time.now.beginning_of_hour) / 60) / 10).round % 2
    Asker.published.select { |a| a.id % 2 == selector }.each do |asker|
      asker.delay.update_relationships()
    end

    # Send mentions to new users
    Asker.mention_new_users

    # Engage backlog
    # Asker.published.each { |asker| asker.send_backlog_new_user_dms() }
  end

  # tmp function - move to engage_new_users
  def self.engage_backlog
    Asker.published.each { |asker| asker.send_backlog_new_user_dms() }
  end

  def self.mention_new_users
    askers = Asker.published
    answered_dm_users = User.where("learner_level = 'dm answer'").includes(:posts)
    app_posts = Post.where("in_reply_to_user_id in (?) and intention = 'new user question mention'", answered_dm_users.collect(&:id)).group_by(&:in_reply_to_user_id)
    popular_asker_publications = {}
    answered_dm_users.each do |user|
      if app_posts[user.id].blank?
        asker = askers.select { |a| a.id == user.posts.first.in_reply_to_user_id }.first
        next unless asker
        unless publication = popular_asker_publications[asker.id]
          if popular_post = asker.posts.includes(:conversations => {:publication => :question}).where("posts.created_at > ? and posts.interaction_type = 1 and questions.id <> ?", 1.week.ago, asker.new_user_q_id).sort_by {|p| p.conversations.size}.last
            publication_id = popular_post.publication_id
          else
            publication_id = asker.posts.where("interaction_type = 1").order("created_at DESC").limit(1).first.publication_id
          end
          publication = Publication.includes(:question).find(publication_id)
          popular_asker_publications[asker.id] = publication
        end
        asker.send_public_message("Next question! #{publication.question.text}", {
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

  def schedule_incorrect_answer_followup user_post
    return false unless question = user_post.in_reply_to_question and publication = user_post.conversation.try(:publication)
    return false if posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ? and question_id = ? and created_at > ?", user_post.user_id, question.id, Time.now - 30.days).present? # check that haven't followed up with them on this question in the past month    
    return false if Delayed::Job.where(attempts: 0).select { |dj| 
        fj = YAML.load(dj.handler).instance_values 
        fj['options'].present? and fj['options'][:intention] == 'incorrect answer follow up' and fj['sender'].id == id and fj['options'][:in_reply_to_user_id] == user_post.user_id 
      }.present? # check if already have scheduled followup    
    last_followup = posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ? and created_at > ?", user_post.user_id, 1.week.ago).order("created_at ASC").last
    return false if last_followup.present? and !Post.exists?(:in_reply_to_user_id => id, :user_id => user_post.user_id, :in_reply_to_post_id => last_followup.id) # check no unresponded followup from past week

    user = user_post.user
    script = "Try this one again: #{question.text}"
    followup_post = TwitterMention.new(self, script, {
      :reply_to => user.twi_screen_name,
      :in_reply_to_user_id => user.id,
      :intention => 'incorrect answer follow up',
      :long_url => "http://wisr.com/questions/#{question.id}/#{question.slug}",
      :publication_id => publication.id,
      :posted_via_app => true, 
      :requires_action => false,
      :interaction_type => 2,
      :link_to_parent => false,
      :link_type => "follow_up",
      :include_answers => true,
      :question_id => question.id      
    })

    interval = Post.create_split_test(user.id, "incorrect answer followup interval in days (answers followup)", '1', '3', '7', '14')
    Delayed::Job.enqueue(
      followup_post,
      :run_at => interval.to_i.days.from_now
    )
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

  def private_response user_post, correct, options = {}
    user = user_post.user
    conversation = options[:conversation]
    if correct.nil?
     response_text = options[:message]
      if response_text == "Refer a friend?"
        response_text = Post.create_split_test(user.id, "Refer a friend script (follower joins)", 
          "Do you have any friends/classmates that would also be interested?",
          "Could you share with a couple of friends/classmates please?"
        )
      else
        response_text = options[:message].gsub("@#{options[:username]}", "")
      end

      response_post = self.delay.send_private_message(user, response_text, {
        :conversation_id => conversation.id,
        :intention => options[:message] == "Refer a friend?" ? 'refer a friend' : nil
      })
    else
      if options[:tell]
        answer_text = Answer.where("question_id = ? and correct = ?", user_post.in_reply_to_question_id, true).first.text
        answer_text = "#{answer_text[0..77]}..." if answer_text.size > 80
        response_text = "I was looking for '#{answer_text}'"
      else
        response_text = generate_response(correct, user_post.in_reply_to_question, options[:tell])
      end

      user_post.update_attribute(:correct, correct)

      # Will double count if we grade people again via DM
      Mixpanel.track_event "answered", {
        :distinct_id => options[:in_reply_to_user_id],
        :time => user_post.created_at.to_i,
        :account => twi_screen_name,
        :type => "twitter",
        :in_reply_to => "new follower question DM"
      }

      user.update_user_interactions({
        :learner_level => "dm answer", 
        :last_interaction_at => user_post.created_at,
        :last_answer_at => user_post.created_at
      }) 

      response_post = self.delay.send_private_message(user, response_text, {
        :conversation_id => conversation.id,
        :intention => 'grade'
      })
    end
    user_post.update_attributes(:requires_action => false, :correct => correct)
    response_post
  end

  # rename public_response
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
      app_post = self.send_public_message(response_text, {
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

    if app_post
      user_post.update_attributes(:requires_action => false, :correct => correct) unless user_post.posted_via_app
      self.delay.after_answer_filter(answerer, user_post, {:learner_level => user_post.posted_via_app ? "feed answer" : "twitter answer"})
      self.delay.update_metrics(answerer, user_post, publication, {:autoresponse => options[:autoresponse]})
      return app_post
    else
      return false
    end
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
      answer = Answer.where("question_id = ? and correct = ?", question.id, true).first
      if question and answer
        response_text = ''
        response_text = "#{['Sorry', 'Not quite', 'No'].sample}, " unless tell
        answer_text = answer.text
        answer_text = "#{answer_text[0..77]}..." if answer_text.size > 80
        response_text +=  "I was looking for '#{answer_text}'"
      else
        response_text = INCORRECT.sample
      end
    end
    response_text
  end


  def auto_respond user_post
    return unless !user_post.autocorrect.nil? and user_post.requires_action
    
    answerer = user_post.user  
    if user_post.is_dm?
      return unless answerer.dm_conversation_history_with_asker(id).grade.blank?
      return if user_post.is_moderatable? and rand <= 0.05 # return 5% of eligible posts for moderation
      interval = Post.create_split_test(answerer.id, "DM autoresponse interval v2 (activity segment +)", "90", "120", "150", "180", "210")
      Delayed::Job.enqueue(
        TwitterPrivateMessage.new(self, answerer, generate_response(user_post.autocorrect, user_post.in_reply_to_question), {:in_reply_to_post_id => user_post.id, :intention => "dm autoresponse"}),
        :run_at => interval.to_i.minutes.from_now
      )
      user_post.update_attribute :correct, user_post.autocorrect
      learner_level = "dm answer"
    else
      return unless user_post.conversation.posts.grade.blank? # makes sure not to regrade already graded convos
      return if user_post.is_moderatable? and rand <= 0.05 # return 5% of eligible posts for moderation
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
    after_answer_filter(answerer, user_post, :learner_level => learner_level)
  end


  def after_answer_filter answerer, user_post, options = {}
    answerer.update_user_interactions({
      :learner_level => options[:learner_level], 
      :last_interaction_at => user_post.created_at,
      :last_answer_at => user_post.created_at
    })
    nudge(answerer)
    if user_post.correct == false and question = user_post.in_reply_to_question
      schedule_incorrect_answer_followup(user_post) 
    end
    after_answer_action(answerer)
  end 

  def after_answer_action answerer
    return unless can_send_requests_to_user?(answerer)

    actions = [
      Proc.new {|answerer| request_new_question(answerer)}, # recurring
      Proc.new {|answerer| request_mod(answerer)}, # recurring
      Proc.new {|answerer| request_new_handle_ugc(answerer)} # recurring
      # Proc.new {|answerer| send_link_to_activity_feed(answerer)} # one time
    ].shuffle

    actions.each do |action|
      break if action.call answerer
    end
  end

  def can_send_requests_to_user? user
    recent_requests = Post.where("created_at > ?", 1.week.ago)\
      .where("in_reply_to_user_id = ? and (intention like ? or intention like ?)", user.id, '%request%', '%solicit%')\
      .order("created_at DESC")\
      .limit(2)
    return true if recent_requests.blank?

    last_request_time = recent_requests.last.created_at
    return false if last_request_time > 4.hours.ago

    return true if recent_requests.size < 2

    recent_requests.each do |request|
      if request.intention == 'request mod'
        return true if user.becomes(Moderator).post_moderations.where('created_at > ?', last_request_time).present?
      elsif request.intention == 'solicit ugc' or request.intention == 'request new handle ugc'
        return true if user.questions.where('created_at > ?', last_request_time).present?
      end
    end
    return false
  end

  def send_link_to_activity_feed user, force = false
    return false if Post.exists?(:in_reply_to_user_id => user.id, :intention => 'send link to activity feed')
    return false unless user.lifecycle_above? 3
    # return false if posts.where("intention = 'lifecycle+' and in_reply_to_user_id = ? and created_at > ?", user.id, 3.days.ago).present? # buffer after lifecycle transition
    
    unless force # used to bypass split for tests
      return false unless Post.create_split_test(user.id, 'send link to activity feed (=> pro)', 'false', 'true') == 'true'
    end

    script = Post.create_split_test(user.id, 'link to activity feed script (=> pro)', 
      "If you're interested, you can see all of your recent activity here: <link>", 
      "Check out all of your recent activity at <link>",
      "You can see your recent recent activity at <link>"
    )
    script.gsub! '<link>', "http://wisr.com/users/#{user.id}/activity"

    self.send_private_message(user, script, {
      :intention => "send link to activity feed"
    })    
  end

  def request_mod user
    return false unless user.lifecycle_above? 2
    return false if user.transitions.lifecycle.where('created_at > ?', 1.hour.ago).present?
    return false if Post.where(in_reply_to_user_id: user.id).where(:intention => 'request mod').where('created_at > ?', 5.days.ago).present?
    llast_solicitation = Post.where(in_reply_to_user_id: user.id).where(:intention => 'request mod').order('created_at DESC').limit(2)[1]
    return false if llast_solicitation.present? and Moderation.where('user_id = ? and created_at > ?', user.id, llast_solicitation.created_at).empty?
    return false unless Post.requires_moderations(user).present?

    ## ALL MUST ***NOT*** CONTAIN MORE FOR TEST TO PASS
    script = Post.create_split_test(user.id, 'mod request script (=> moderate answer)', 
      "I'd love some help grading my followers... if you would, grade a few responses at <link>", 
      "You're pretty good with this material... would you help grade a few responses at <link>"
    )

    # overwrite script if user has mod'ed before
    ## ALL MUST CONTAIN MORE FOR TEST TO PASS
    if Moderation.exists?(user_id: user.id)
      script = [
        "Do you have a sec to moderate a few more questions? <link>",
        "Thanks for the help so far! Have time to grade a few more? <link>",
        "Have a second to grade a few more questions? <link>",
        "Thanks again for helping grade. Could you help grade a few more? <link>",
        "Have a sec to grade a few more answers? <link>",
        "Could I trouble you for a bit more grading assistance? <link>",
        "Would you grade a few more? <link>",
        "Could you help grade a few more? <link>",
        "Would you grade a few more answers? <link>",
        "Would you mind grading a few more? <link>"
      ].sample  
    end

    link = authenticated_link('http://wisr.com/moderations/manage', user, (Time.now + 1.week))
    script.gsub! '<link>', link

    user.update_attribute :role, "moderator" unless user.is_role?('admin')
    self.send_private_message(user, script, {intention: 'request mod'})
    Mixpanel.track_event "request mod", {:distinct_id => user.id, :account => self.twi_screen_name}    
  end

  def request_new_question user
    return false if user.posts.where("correct = ? and in_reply_to_user_id = ?", true, id).size < 10
    return false if Post.where("in_reply_to_user_id = ? and intention = 'solicit ugc' and created_at > ?", user.id, 2.weeks.ago).size > 0 # we haven't asked them in the past two weeks
    
    llast_solicitation = Post.where(in_reply_to_user_id: user.id).where(:intention => 'solicit ugc').order('created_at DESC').limit(2)[1]
    return false if llast_solicitation.present? and questions.where("user_id = ? and created_at > ?", user.id, llast_solicitation.created_at).count < 1 # the user hasn't received more than one uncompleted solicitation    
    
    script = Post.create_split_test(user.id, "ugc script v4.0", 
      "You know this material pretty well, how about writing a question or two? Enter it at wisr.com/feeds/{asker_id}?q=1", 
      "I'd love to have you write a question or two for this handle... if you would, enter it at wisr.com/feeds/{asker_id}?q=1"
    )
    script.gsub! "{asker_id}", self.id.to_s
    script.gsub! "{asker_name}", self.twi_screen_name

    question_count = user.get_my_questions_answered_this_week_count

    if questions.where(user_id: user.id).present?
      if question_count > 2
        script = [
          "<last_week> Do you have a sec to write a few more? <link>",
          "<last_week> Have a second to write a few more? <link>",
          "<last_week> Have a sec to write a few more? <link>",
          "<last_week> Thanks again for contributing! If you'd like to add more: <link>",
          "<last_week> Would you to write a couple more? <link>",
          "<last_week> Would you write a few more? <link>",
          "<last_week> Would you mind writing a few more? <link>",
          "<last_week> Any more you'd like to add? <link>"
        ].sample
      else
        script = [
          "Do you have a sec to write a few more questions? <link>",
          "Have a second to write a few more questions? <link>",
          "Have a sec to write a few more questions? <link>",
          "If you'd like to add more questions: <link>",
          "Could I trouble you to write a couple more questions? <link>",
          "Would you write a few more questions? <link>",
          "Would you mind writing a few more questions? <link>",
          "Any more questions you'd like to add? <link>"
        ].sample
      end
    end
    
    script.gsub! "<link>", "www.wisr.com/askers/#{id}/questions"
    script.gsub! "<last_week>", "Your question(s) were answered #{question_count} times last week!"

    if Post.create_split_test(user.id, 'ugc request type', 'mention', 'dm') == 'dm'
      self.send_private_message(user, script, {
        :intention => "solicit ugc"
      })
    else
      self.send_public_message(script, {
        :reply_to => user.twi_screen_name,
        :in_reply_to_user_id => user.id,
        :intention => 'solicit ugc',
        :interaction_type => 2
      })
    end
    return true
  end

  def request_new_handle_ugc user
    return false unless user.lifecycle_above? 2
    return false if Post.where("in_reply_to_user_id = ? and intention = 'request new handle ugc' and created_at > ?", user.id, 1.week.ago).size > 0 # we haven't asked them in the past week
    in_progress_askers = Asker.in_progress_askers
    user_askers_with_enough_answers_ids = user.posts.answers\
      .where("in_reply_to_user_id in (?)", in_progress_askers.collect(&:related_askers).flatten.collect(&:id))\
      .group("in_reply_to_user_id")\
      .count.select {|k, v| v > 10}.keys
    in_progress_asker = in_progress_askers.select { |asker| (user_askers_with_enough_answers_ids & asker.related_askers.collect(&:id)).present? }.sample
    return false if in_progress_asker.blank? # user has answered enough questions on a related handle in the past month
    llast_solicitation = Post.where(in_reply_to_user_id: user.id).where(:intention => 'request new handle ugc').order('created_at DESC').limit(2)[1]
    return false if llast_solicitation.present? and Question.where("user_id = ? and created_at > ? and created_for_asker_id = ?", user.id, llast_solicitation.created_at, in_progress_asker.id).count < 1 # the user hasn't received more than one uncompleted solicitation
    
    ## ALL MUST ***NOT*** CONTAIN 'MORE' FOR TEST TO PASS
    script = Post.create_split_test(user.id, 'new handle ugc request script v2 (=> add question)', 
      "Hey, we're working on questions for @<new handle>, could you add one? <link>",
      "We're making @<new handle>, could you write a question for it? <link>"
    )
    
    # overwrite script if user has added UGC to this handle before
    ## ALL MUST CONTAIN 'MORE' FOR TEST TO PASS
    if Question.exists?(user_id: user.id, created_for_asker_id: in_progress_asker.id)
      script = [
        "Do you have a sec to write a few more questions for @<new handle>? <link>",
        "Have a second to write a few more questions for @<new handle>? <link>",
        "Thanks again for contributing questions. Could you write a few more? <link>",
        "Have a sec to write a few more questions? <link>",
        "Could I trouble you to write a couple more questions for @<new handle>? <link>",
        "Would you write a few more questions for @<new handle>? <link>",
        "Would you mind writing a few more questions for @<new handle>? <link>",
        "We're looking for more questions for @<new handle>. Can you write a couple? <link>"
      ].sample
    end

    script.gsub! '<link>', "http://www.wisr.com/askers/#{in_progress_asker.id}/questions"
    script.gsub! '<new handle>', in_progress_asker.twi_screen_name

    self.send_private_message(user, script, {intention: 'request new handle ugc'})
    Mixpanel.track_event "request new handle ugc", {:distinct_id => user.id, :account => twi_screen_name, :in_progress_asker => in_progress_asker.twi_screen_name}
  end

  def nudge answerer
    return unless client and nudge_type = client.nudge_types.automatic.active.sample and answerer.nudge_types.blank? and answerer.posts.answers.where(:correct => true, :in_reply_to_user_id => id).size > 2 and answerer.is_follower_of?(self)

    if client.id == 14699
      nudge_type = NudgeType.find_by_text(Post.create_split_test(answerer.id, "SATHabit copy (click-through) < 123 >", 
        "You're doing really well! I offer a much more comprehensive (free) course here: {link}",
        "Nice work so far! You can practice with customized questions at: {link}",
        "Want to see how you would score on the SAT? Check it out: {link}",
        "Hey, if you're interested, you can get a personalized SAT question of the day at {link}",
        "You've answered {x} questions, with just {25-x} more you could have gotten an SAT score! Get one here: {link}"
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
  end

  ## Update metrics

  def update_metrics answerer, user_post, publication, options = {}
    in_reply_to = nil
    strategy = nil
    if user_post.posted_via_app
      # Check if in response to re-engage message
      last_inactive_reengagement = Post.where("(intention = ? or is_reengagement = ?) and in_reply_to_user_id = ? and publication_id = ?", 'reengage inactive', true, answerer.id, publication.id).order("created_at DESC").limit(1).first
      if last_inactive_reengagement.present? and Post.joins(:conversation).where("posts.id <> ? and posts.user_id = ? and posts.correct is not null and posts.created_at > ? and conversations.publication_id = ?", user_post.id, answerer.id, last_inactive_reengagement.created_at, publication.id).blank?
        Post.trigger_split_test(answerer.id, 'reengage last week inactive') 
        strategy = answerer.get_experiment_option("reengagement intervals (age > 15 days)") if answerer.enrolled_in_experiment?("reengagement intervals (age > 15 days)")
        in_reply_to = "reengage inactive"
      end

      # Check if in response to incorrect answer follow-up
      unless in_reply_to
        last_followup = Post.where("intention = ? and in_reply_to_user_id = ? and publication_id = ?", 'incorrect answer follow up', answerer.id, publication.id).order("created_at DESC").limit(1).first
        if last_followup.present? and Post.joins(:conversation).where("posts.id <> ? and posts.user_id = ? and posts.correct is not null and posts.created_at > ? and conversations.publication_id = ?", user_post.id,  answerer.id, last_followup.created_at, publication.id).blank?
          in_reply_to = "incorrect answer follow up" 
          Post.trigger_split_test(answerer.id, "incorrect answer followup interval in days (answers followup)") unless user_post.correct.nil?
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
        if parent_post.intention == 'reengage inactive' or parent_post.is_reengagement == true
          Post.trigger_split_test(answerer.id, 'reengage last week inactive') 
          strategy = answerer.get_experiment_option("reengagement intervals (age > 15 days)") if answerer.enrolled_in_experiment?("reengagement intervals (age > 15 days)")
          in_reply_to = "reengage inactive"
        elsif parent_post.intention == 'incorrect answer follow up'
          in_reply_to = "incorrect answer follow up" 
          Post.trigger_split_test(answerer.id, "incorrect answer followup interval in days (answers followup)") unless user_post.correct.nil?
        elsif parent_post.intention == 'new user question mention'
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

  ## Weekly progress reports

  def self.send_progress_reports
    recipients = Asker.select_progress_report_recipients()
    email_recipients = recipients.select { |r| r.email.present? }
    # dm_recipients = (recipients - email_recipients)

    Asker.send_progress_report_emails(email_recipients)
    # Asker.send_progress_report_dms(dm_recipients)
  end

  def self.select_progress_report_recipients
    User.includes(:posts).not_asker_not_us.where("users.subscribed = ? and posts.correct is not null and posts.created_at > ? and posts.in_reply_to_user_id in (?)", true, 1.week.ago, Asker.ids).reject { |user| user.posts.size < 3 }
  end

  def self.send_progress_report_emails recipients
    asker_hash = Asker.published.group_by(&:id)
    recipients.each do |recipient| 
      if Post.create_split_test(recipient.id, "weekly progress report email (=> superuser)", "false", "true") == "true"
        begin
          UserMailer.progress_report(recipient, recipient.activity_summary(since: 1.week.ago, include_ugc: true, include_progress: true), asker_hash).deliver 
          Mixpanel.track_event "progress report email sent", { :distinct_id => recipient.id }
        rescue Exception => exception
          puts "Failed to send progress report to #{recipient.email} (#{exception})"
        end         
      end
    end
  end

  def self.send_progress_report_dms recipients
    asker_hash = Asker.all.group_by(&:id)
    recipients.each do |recipient|
      asker, text = Asker.compose_progress_report(recipient, asker_hash)
      next unless asker and text
      
      if asker.followers.include?(recipient) and Post.create_split_test(recipient.id, "weekly progress report", "false", "true") == "true"
        asker.send_private_message(recipient, text, {:intention => "progress report"})
        # puts "sending: '#{text}' to #{recipient.twi_screen_name} from #{asker.twi_screen_name}"
        sleep 1
      end
    end
  end

  def self.compose_progress_report recipient, asker_hash
    script = "Last week:"
    primary_asker = asker_hash[recipient.posts.collect(&:in_reply_to_user_id).group_by { |e| e }.values.max_by(&:size).first].first
    activity_hash = recipient.activity_summary(since: 1.week.ago)[:answers]
    ugc_answered_count = recipient.get_my_questions_answered_this_week_count

    activity_hash.each_with_index do |(asker_id, activity), i|
      return nil, nil unless asker_hash[asker_id].present?
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
    Asker.published.each do |asker|
      next unless related_asker = asker.related_askers.published.sample
      next unless publication = related_asker.publications.includes(:posts).published.order('updated_at DESC').limit(5).sample
      next unless post = publication.posts.statuses.sample
      Post.twitter_request { asker.twitter.retweet(post.provider_post_id) }
      if Time.now.hour % 12 == 0
        asker.send_public_message("Want me to publish YOUR questions? Click the link: wisr.com/feeds/#{asker.id}?q=1", {
          :intention => 'solicit ugc',
          :interaction_type => 2
        })
      end  
      sleep 1  
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
      next unless asker.followers.collect(&:twi_user_id).include? user.twi_user_id
      script = "So far, #{question_data[:answered_count]} people have answered your question "
      script += ((question_data[:text].size + 2) > (140 - script.size)) ? "'#{question_data[:text][0..(140 - 6 - script.size)]}...'" : "'#{question_data[:text]}'"
      asker.send_private_message(user, script, {:intention => "author followup"})
      
      if Post.create_split_test(user.id, 'author followup type (return ugc submission)', 'write another here', 'direct to dashboard') == 'write another here'
        script = "#{PROGRESS_COMPLEMENTS.sample} Write another here: wisr.com/feeds/#{asker.id}?q=1 (or DM it to me)"
      else
        script = "Check out your dashboard here: #{URL}/askers/#{asker.id}/questions"
      end

      asker.send_private_message(user, script, {:intention => "author followup"})
      Mixpanel.track_event "author followup sent", {:distinct_id => user_id}
    end
  end


  # Nudge followups

  def self.send_nudge_followups
    Asker.dm_nudge_followups(Asker.get_nudge_followup_recipients())
  end

  def self.get_nudge_followup_recipients recipient_hash = {}
    # no_reply_nudges = Post.includes(:child).where("posts.id not in (select distinct(children_posts.in_reply_to_post_id))")
    nudges = Post.nudge.where("created_at > ? and created_at < ?", 1.week.ago, 1.day.ago)
    nudge_recipient_ids = nudges.collect(&:in_reply_to_user_id).uniq
    nudge_response_user_ids = Post.where("user_id in (?) and in_reply_to_post_id in (?)", nudge_recipient_ids, nudges.collect(&:id)).collect(&:user_id).uniq
    already_followed_up_user_ids = Post.where("intention = ? and in_reply_to_user_id in (?)", 'nudge followup', nudge_recipient_ids).collect(&:in_reply_to_user_id).uniq
    nudges.each do |nudge| 
      next if (nudge_response_user_ids + already_followed_up_user_ids).include? nudge.in_reply_to_user_id # filter out users who have responded to our nudge or who have already been followed up with
      recipient_hash[nudge.in_reply_to_user_id] = {converted: nudge.converted, asker_id: nudge.user_id, post_id: nudge.id}
    end
    recipient_hash
  end

  def self.dm_nudge_followups recipient_hash
    recipient_hash.each do |recipient_id, recipient_data|
      asker = Asker.find(recipient_data[:asker_id])
      next unless asker.published
      
      if Post.create_split_test(recipient_id, "nudge followup (nudge conversion)", "false", "true") == "true"
        user = User.find(recipient_id)
        script = "You have a chance to check out that link? What did you think?"
        asker.send_private_message(user, script, {intention: "nudge followup", in_reply_to_post_id: recipient_data[:post_id]})
        Mixpanel.track_event "nudge followup sent", {:distinct_id => user.id}
      end 
    end
  end

  def most_popular_question options = {}
    options.reverse_merge!(:since => 99.years.ago, :character_limit => 9999)
    if options[:exclude_strings]
      posts = Post.joins(:in_reply_to_question)\
        .answers\
        .mentions\
        .where("questions.text not similar to ?", "%(#{options[:exclude_strings].join('|')})%")\
        .where("posts.in_reply_to_user_id = ?", id)\
        .where("posts.created_at > ?", options[:since])\
        .where("length(questions.text) < ?", options[:character_limit])\
        .group("posts.in_reply_to_question_id")\
        .count
      if posts.blank?
        posts = Post.joins(:in_reply_to_question)\
          .answers\
          .mentions\
          .where("questions.text not similar to ?", "%(#{options[:exclude_strings].join('|')})%")\
          .where("posts.in_reply_to_user_id = ?", id)\
          .where("length(questions.text) < ?", options[:character_limit])\
          .group("posts.in_reply_to_question_id")\
          .count
      end
    else
      posts = Post.joins(:in_reply_to_question)\
        .answers\
        .mentions\
        .where("posts.in_reply_to_user_id = ?", id)\
        .where("posts.created_at > ?", options[:since])\
        .where("length(questions.text) < ?", options[:character_limit])\
        .group("posts.in_reply_to_question_id")\
        .count
      if posts.blank?
        posts = Post.joins(:in_reply_to_question)\
          .answers\
          .mentions\
          .where("posts.in_reply_to_user_id = ?", id)\
          .where("length(questions.text) < ?", options[:character_limit])\
          .group("posts.in_reply_to_question_id")\
          .count
      end
    end
    question_id = posts.max{|a,b| a[1] <=> b[1]}.try(:first) || new_user_q_id || questions.first.id
    Question.find(question_id)
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

  def seeder_import seeder_id = nil
    return unless seeder_id

    #get cards from seeder
    url = URI.parse("http://seeder.herokuapp.com/handles/#{seeder_id}/export.json")
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    
    begin
      data = JSON.parse(res.body)
      cards = data["questions"]
      topic = data["topic"]
    rescue
      cards=[]
    end

    if topic and !topic.empty? and (description.nil? or description.empty?)
      _description = "Daily quiz questions on ##{topic}. Tweet me your answers!"
      profile = {:description => _description}
      update_attribute :description, _description
      twitter.update_profile profile
      topics << Topic.create({ name: topic })
    end

    cards.each_with_index do |card, i|
      q = Question.find_or_create_by_seeder_id(card['card_id'])
      answers = q.answers
      f_answers = []
      t_answer = nil
      answers.each do |a|
        t_answer = a.text if a.correct
        f_answers << a.text unless a.correct        
      end 
      card_f_answers = card['false_answers']
      unless q.text == card['text'] &&
              q.created_for_asker_id == id &&
              t_answer == card['answer']
        q.update_attributes(:text => card['text'],
                            :user_id => 1,
                            :status => 1,
                            :created_for_asker_id => id)
        q.answers.destroy_all unless q.answers.blank?
        q.answers << Answer.create(:text => card['answer'], :correct => true)
        card['false_answers'].each do |fa|
          q.answers << Answer.create(:text => fa, :correct => false)
        end
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

  def self.autofollow_summary
    Asker.includes(:follow_relationships).find(AUTOFOLLOW_ASKER_IDS).each do |asker|
      puts "Follow Summary for #{asker.twi_screen_name}"
      puts "===================="
      puts "\n"
      asker.follow_relationships.group_by { |r| r.updated_at.to_date }.sort.reverse.each do |date, relationships|
        puts "#{date.strftime('%m/%d')}:"
        puts "------"
        puts "Total: #{relationships.select { |r| r.active == true }.count}"
        puts "Unknown: #{relationships.select { |r| r.active == true and r.type_id == nil }.count}"
        puts "Followback: #{relationships.select { |r| r.active == true and r.type_id == 1 }.count}"
        puts "Search: #{relationships.select { |r| r.active == true and r.type_id == 2 }.count}"
        puts "Unfollows: #{relationships.select { |r| r.active == false }.count}"
        # puts "Organic: #{relationships.select { |r| r.type_id == 3 }.count}"
        puts "\n"
      end
      puts "\n\n"
    end
  end   
end
