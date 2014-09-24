class Asker < User
  include ManageTwitterRelationships
  include EngagementEngine::ReengageInactive
  include EngagementEngine::AutoRespond

  include AuthorizationsHelper

  belongs_to :client
  belongs_to :new_user_question, :class_name => 'Question', :foreign_key => :new_user_q_id

  has_many :questions, :foreign_key => :created_for_asker_id
  has_many :moderators, -> { where("relationships.active = ? and role = 'moderator'", true) }, :through => :follower_relationships, :source => :follower
  has_many :issuances

  has_and_belongs_to_many :related_askers, -> { uniq }, class_name: 'Asker', join_table: :related_askers, foreign_key: :asker_id, association_foreign_key: :related_asker_id
  has_and_belongs_to_many :topics, -> { uniq }, join_table: :askers_topics

  default_scope -> { where(role: 'asker') }

  scope :published, -> { where("published = ?", true) }


  def self.ids
    Rails.cache.fetch('asker_ids', :expires_in => 5.minutes){Asker.all.collect(&:id)}
  end

  def self.published_ids
    Rails.cache.fetch('published_asker_ids', :expires_in => 5.minutes){Asker.published.collect(&:id)}
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

  def self.wisr
    Asker.where(id: 8765).first
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

  def send_public_message text, options = {}
    recipient = User.where(id: options[:in_reply_to_user_id]).first
    communication_preference = recipient.blank? ? 1 : recipient.communication_preference
    case communication_preference
    when 1
      self.becomes(TwitterAsker).send_public_message(text, options, recipient)
    when 2
      self.becomes(EmailAsker).send_public_message(text, options, recipient)
    when 3
      self.becomes(IphoneAsker).send_public_message(text, options, recipient)
    else
      raise 'no public send method for that communication preference'
    end
  end

  def send_private_message recipient, text, options = {}
    recipient ||= User.where(id: options[:in_reply_to_user_id]).first
    communication_preference = recipient.blank? ? 1 : recipient.communication_preference
    case communication_preference
    when 1
      self.becomes(TwitterAsker).send_private_message(recipient, text, options)
    when 2
      self.becomes(EmailAsker).send_private_message(recipient, text, options)
    when 3
      self.becomes(IphoneAsker).send_private_message(recipient, text, options)
    else
      raise 'no private send method for that communication preference'
    end
  end

  def publish_question
    queue = self.publication_queue

    unless queue.blank?
      publication = queue.publications.order("id ASC")[queue.index]
      PROVIDERS.each { |provider| Post.publish(provider, self, publication) }

      if publication.first_posted_at.nil?
        publication.update first_posted_at: Time.now
      end

      queue.increment_index(self.posts_per_day)
    end
  end

  def send_new_user_question user, options = {}
    return if posts.where("intention = 'initial question dm' and in_reply_to_user_id = ?", user.id).size > 0
    dm_text = "Here's your first question! "
    question = most_popular_question :character_limit => (140 - dm_text.size), exclude_strings: ["the following"]

    dm_text += question.text
    answers = " (#{question.answers.shuffle.collect {|a| a.text}.join('; ')})"
    dm_text += answers if (INCLUDE_ANSWERS.include?(id) and ((dm_text + answers).size < 141) and !question.text.include?("T/F") and !question.text.include?("T:F"))

    self.send_private_message(user, dm_text, {
      :question_id => question.id,
      :intention => "initial question dm"})

    MP.track_event "DM question to new follower", {
      :distinct_id => user.id,
      :account => twi_screen_name,
      :backlog => options[:backlog] == true ? true : false
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

  # @todo route all question through this method -- including reengage user
  # @todo add test coverage for this method -- currently none
  def next_question user, options = {}
    question = select_question(user)
    publication = question.publications.order("created_at DESC").first
    long_url = publication ? "#{URL}/feeds/#{id}/#{publication.id}" : nil
    if options[:type] == :private # Not tested yet...
      self.send_private_message(user, question.text, {
        posted_via_app: true,
        requires_action: false,
        link_type: options[:link_type],
        intention: options[:intention],
        in_reply_to_user_id: user.id,
        include_answers: true,
        is_reengagement: true,
        publication_id: (publication ? publication.id : nil),
        question_id: (question ? question.id : nil),
        long_url: long_url
      })
    else
      self.send_public_message(question.text, {
        reply_to: user.twi_screen_name,
        long_url: options[:long_url],
        in_reply_to_user_id: user.id,
        posted_via_app: true,
        requires_action: false,
        link_to_parent: false,
        link_type: options[:link_type],
        intention: options[:intention],
        include_answers: true,
        publication_id: (publication ? publication.id : nil),
        question_id: (question ? question.id : nil),
        long_url: long_url
      })
    end
  end

  def select_question user
    scored_questions = Question.score_questions
    scored_questions = scored_questions[id]
    return nil if scored_questions.nil?

    reengagement_question_ids = posts\
      .reengage_inactive\
      .where("in_reply_to_user_id = ?", user.id)\
      .where("question_id is not null")\
      .collect(&:question_id)\
      .uniq

    # filter out answered and recently sent question ids if possible
    question_ids = scored_questions.keys - user.questions_answered_ids_by_asker(id) # get unanswered questions
    question_ids = scored_questions.keys if question_ids.blank? # degrade to using answered questions
    question_ids = question_ids.reject { |id| reengagement_question_ids.include? user.id } if (question_ids - reengagement_question_ids).present? # filter questions sent recently as reengagments but not answered

    score_grouped_question_ids = question_ids.group_by { |question_id| scored_questions[question_id] }

    # select question from highest scoring question group
    Question.includes(:publications).find(score_grouped_question_ids.max[1].sample)
  end

  def self.engage_new_users
    # Send DMs to new users
    selector = (((Time.now - Time.now.beginning_of_hour) / 60) / 10).round % 2
    Asker.published.select { |a| a.id % 2 == selector }.each do |asker|
      asker.delay.update_relationships()
    end

    # Send mentions to new users
    Asker.mention_new_users
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
          popular_post = asker.posts
            .includes(:conversations => {:publication => :question})
            .where("posts.created_at > ? and posts.interaction_type = 1 and questions.id <> ?",
              1.week.ago,
              asker.new_user_q_id)
            .references(:question)
            .sort_by {|p| p.conversations.size}.last

          if popular_post
            publication_id = popular_post.publication_id
          else
            publication_id = asker.posts.where("interaction_type = 1").order("created_at DESC").limit(1).first.publication_id
          end
          publication = Publication.includes(:question).find(publication_id)
          popular_asker_publications[asker.id] = publication
        end
        asker.send_public_message("Next question! #{publication.question.text}", {
          :reply_to => user.twi_screen_name,
          :long_url => "#{URL}/#{asker.subject_url}/#{publication.id}",
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
        MP.track_event "new user question mention", {
          :distinct_id => user.id,
          :account => asker.twi_screen_name
        }
      end
    end
  end

  def schedule_correct_answer_followup user_post
    return false unless question = user_post.in_reply_to_question and publication = user_post.conversation.try(:publication)
    return false unless user_post.is_email? # only if email
    return false if user_post.parent.intention == 'correct answer follow up' # only if post is not already a followup

    user = user_post.user
    script = question.text
    followup_post = EmailPrivateMessage.new(self, user, script, {
      in_reply_to_user_id: user.id,
      intention: 'correct answer follow up',
      long_url: "#{URL}/feeds/#{id}/#{publication.id}",
      publication_id: publication.id,
      posted_via_app: true,
      requires_action: false,
      link_to_parent: false,
      link_type: "follow_up",
      include_answers: false,
      question_id: question.id,
      subject: 'Followup'
    })

    Delayed::Job.enqueue(
      followup_post,
      :run_at => 1.day.from_now
    )
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
      :long_url => "#{URL}/questions/#{question.id}/#{question.slug}",
      :publication_id => publication.id,
      :posted_via_app => true,
      :requires_action => false,
      :interaction_type => 2,
      :link_to_parent => false,
      :link_type => "follow_up",
      :include_answers => true,
      :question_id => question.id
    })

    Delayed::Job.enqueue(
      followup_post,
      :run_at => 1.day.from_now
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
      response_text = options[:message].gsub("@#{options[:username]}", "")

      #  @todo remove if exception not thrown
      if response_text == "Refer a friend?"
        throw "Refer a friend not fully cleaned up"
      end

      response_post = self.delay.send_private_message(user, response_text, {
        :conversation_id => conversation.id})
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
      MP.track_event "answered", {
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
    publication = user_post.conversation.try(:publication)

    answerer = user_post.user
    question = user_post.link_to_question
    resource_url = nil

    publication ||= user_post.parent.try(:publication)
    publication ||= Publication.find_or_create_by_question_id question.id, self.id

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
        :long_url => "#{URL}/#{subject_url}/#{publication.id}",
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
      self.delay.update_metrics(answerer, user_post, publication, {
        autoresponse: options[:autoresponse],
        type: options[:type]})
      return app_post
    else
      return false
    end
  end

  def format_manager_response user_post, correct, answerer, publication, question, options = {}
    response_text = generate_response(correct, question)
    if correct and options[:quote_user_answer]
      cleaned_user_post = user_post.text.gsub /@[A-Za-z0-9_]* /, ""
      cleaned_user_post = "#{cleaned_user_post[0..47]}..." if cleaned_user_post.size > 50
      response_text += " RT '#{cleaned_user_post}'"
      resource_url = nil
    elsif !correct
      resource_url = publication.question.resource_url if publication.question.resource_url
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

  def after_answer_filter answerer, user_post, options = {}
    answerer.update_user_interactions({
      :learner_level => options[:learner_level],
      :last_interaction_at => user_post.created_at,
      :last_answer_at => user_post.created_at
    })
    nudge(answerer)
    if user_post.correct == false and question = user_post.in_reply_to_question
      schedule_incorrect_answer_followup(user_post)
    elsif user_post.correct == true and user_post.in_reply_to_question
      schedule_correct_answer_followup(user_post)
    end
    after_answer_action(answerer)
  end

  def after_answer_action answerer
    return unless can_send_requests_to_user?(answerer)

    actions = [
      # Proc.new {|answerer| request_new_question(answerer)}, # recurring
      Proc.new {|answerer| request_mod(answerer)} #, # recurring
      # Proc.new {|answerer| request_new_handle_ugc(answerer)} # recurring
    ]
    # this is a hack to cut down on extremely slow tests
    actions = actions.shuffle unless Rails.env.test?

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
        return true if user.becomes(Moderator).moderations.where('created_at > ?', last_request_time).present?
      elsif request.intention == 'solicit ugc' or request.intention == 'request new handle ugc'
        return true if user.questions.where('created_at > ?', last_request_time).present?
      end
    end
    return false
  end

  def request_mod user
    return false unless user.lifecycle_above? 2
    return false if user.transitions.lifecycle.where('created_at > ?', 1.hour.ago).present?
    return false if Post.where(in_reply_to_user_id: user.id).where(:intention => 'request mod').where('created_at > ?', 5.days.ago).present?
    llast_solicitation = Post.where(in_reply_to_user_id: user.id).where(:intention => 'request mod').order('created_at DESC').limit(2)[1]
    return false if llast_solicitation.present? and Moderation.where('user_id = ? and created_at > ?', user.id, llast_solicitation.created_at).empty?
    return false unless (Post.requires_moderations(user).present? or Question.requires_moderations(user).present?)

    ## ALL MUST ***NOT*** CONTAIN MORE FOR TEST TO PASS
    script = [
      "If you would, grade a few answers here <link>",
      "Have a look at a few answers here from other users: <link>",
      "Help grade other users here: <link>",
      "Could you help grade a few from other users? <link>",
      "Would you mind grading a few from others? <link>",

      "I'm a bit behind grading... could you help? <link>",
      "I'm a bit behind replying to answer... could you help? <link>",

      "You seem to know your stuff -- could you help me grade? <link>",
      "You're good at this -- could you help me grade? <link>",
      "You're doing well with these questions -- would you help me grade? <link>",
      "You're doing well at this -- can you help grade? <link>"
    ].sample

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

    link = authenticated_link("#{URL}/moderations/manage", user, (Time.now + 1.week))
    script.gsub! '<link>', link

    user.update role: "moderator" unless user.is_role?('admin')
    self.send_private_message(user, script, {intention: 'request mod', subject: 'Moderate?'})
    MP.track_event "request mod", {:distinct_id => user.id, :account => self.twi_screen_name}

    true
  end

  def request_feedback_on_question question
    # find mods who have been active recently
    recently_active_user_ids = Asker.get_ids_to_last_active_at(7).keys
    recently_active_moderators = moderators
      .where('users.id != ?', question.user_id || 0)
      .select { |moderator| recently_active_user_ids.include?(moderator.id) }
    recently_active_question_moderators = Moderator
      .where(id: recently_active_moderators.collect(&:id))
      .joins(:question_moderations)
      .readonly(false).uniq.to_a

    # exclude mods who recently received a feedback request in the past week
    user_ids_with_recent_feedback_requests = posts
      .where(intention: 'request question feedback')\
      .where('created_at > ?', 1.week.ago)\
      .select([:intention, :in_reply_to_user_id, :created_at])\
      .collect(&:in_reply_to_user_id)
    recently_active_question_moderators.reject! do |moderator|
      user_ids_with_recent_feedback_requests.include?(moderator.id)
    end

    # exclude mods who have received any type of request in the past three days
    user_ids_with_recent_requests = posts.where("created_at > ?", 3.days.ago)
      .where("intention like ? or intention like ?", '%request%', '%solicit%')
      .order("created_at DESC")\
      .collect(&:in_reply_to_user_id)
    recently_active_question_moderators.reject! do |moderator|
      user_ids_with_recent_requests.include?(moderator.id)
    end

    link = "http://www.wisr.com/moderations/manage?question_id=#{question.id}"

    recently_active_question_moderators.sample(3).each do |moderator|
      script = [
        "Somebody wrote a question, could you edit it? <link>",
        "Another user just authored a question, could you check it? <link>",
        "Could you see if one of our new questions needs to be edited? <link>",
        "Would you mind taking a look at a new question we'd like to add? <link>",
        "Do you mind looking at a question one of our users recently wrote? <link>"
      ].sample

      link_with_token = authenticated_link(link, moderator, (Time.now + 1.week))
      script.gsub! "<link>", link_with_token
      self.send_private_message(moderator, script, {
        :intention => "request question feedback"
      })

      MP.track_event("request question feedback",
          distinct_id: moderator.id,
          account: twi_screen_name)
    end
  end

  def nudge answerer
    return unless client and nudge_type = client.nudge_types.automatic.active.sample and answerer.nudge_types.blank? and answerer.posts.answers.where(:correct => true, :in_reply_to_user_id => id).size > 2 and answerer.is_follower_of?(self)

    if client.id == 14699
      nudge_type = NudgeType.find_by_text([
        "You're doing really well! I offer a much more comprehensive (free) course here: {link}",
        "Nice work so far! You can practice with customized questions at: {link}",
        "Want to see how you would score on the SAT? Check it out: {link}",
        "Hey, if you're interested, you can get a personalized SAT question of the day at {link}",
        "You've answered {x} questions, with just {25-x} more you could have gotten an SAT score! Get one here: {link}"].sample)
      if nudge_type.text.include? "{x}"
        question_count = answerer.posts.answers.where(:in_reply_to_user_id => id).size
        nudge_type.text = nudge_type.text.gsub "{x}", question_count.to_s
        nudge_type.text = nudge_type.text.gsub "{25-x}", (25 - question_count).to_s
      end
      nudge_type.send_to(self, answerer)

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
      MP.track_event "answered", {
        distinct_id: answerer.id,
        account: self.twi_screen_name,
        type: options[:type],
        in_reply_to: in_reply_to,
        strategy: strategy,
        question_status: user_post.in_reply_to_question.status
      }
    else
      parent_post = user_post.parent
      if parent_post.present?
        if parent_post.intention == 'reengage inactive' or parent_post.is_reengagement == true
          in_reply_to = "reengage inactive"
        elsif parent_post.intention == 'incorrect answer follow up'
          in_reply_to = "incorrect answer follow up"
        elsif parent_post.intention == 'new user question mention'
          in_reply_to = "new follower question mention"
        end
      end

      # Fire mixpanel answer event
      MP.track_event "answered", {
        distinct_id: answerer.id,
        time: user_post.created_at.to_i,
        account: self.twi_screen_name,
        type: 'twitter',
        in_reply_to: in_reply_to,
        strategy: strategy,
        interaction_type: user_post.interaction_type,
        autoresponse: (options[:autoresponse].present? ? options[:autoresponse] : false)
      }
    end
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
      begin
        UserMailer.progress_report(recipient, recipient.activity_summary(since: 1.week.ago, include_ugc: true, include_progress: true), asker_hash).deliver
        MP.track_event "progress report email sent", { :distinct_id => recipient.id }
      rescue Exception => exception
        puts "Failed to send progress report to #{recipient.email} (#{exception})"
      end
    end
  end

  def self.send_progress_report_dms recipients
    asker_hash = Asker.all.group_by(&:id)
    recipients.each do |recipient|
      asker, text = Asker.compose_progress_report(recipient, asker_hash)
      next unless asker and text

      if asker.followers.include?(recipient)
        asker.send_private_message(recipient, text, {:intention => "progress report"})
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

      script = ["#{PROGRESS_COMPLEMENTS.sample} Write another here: wisr.com/feeds/#{asker.id}?q=1 (or DM it to me)",
                "Check out your dashboard here: #{URL}/askers/#{asker.id}/questions"].sample

      asker.send_private_message(user, script, {:intention => "author followup"})
      MP.track_event "author followup sent", {:distinct_id => user_id}
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

      user = User.find(recipient_id)
      script = "You have a chance to check out that link? What did you think?"
      asker.send_private_message(user, script, {intention: "nudge followup", in_reply_to_post_id: recipient_data[:post_id]})
      MP.track_event "nudge followup sent", {:distinct_id => user.id}
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

  def notify_badge_issued user, badge, options
    message = "@#{user.twi_screen_name} You earned the #{badge.title} badge, congratulations!"

    post = send_public_message message, options
    MP.track_event "badge", {distinct_id: user.id, badge: badge.title}
    post
  end

  def subject_url
    _subject = subject || ''
    _subject = _subject.downcase
    _subject = _subject.gsub(' ', '-')

    _subject
  end

  def self.find_by_subject_url subject_url
    Rails.cache.fetch("Asker.find_by_subject_url(#{subject_url})", :expires_in => 1.hour) do
      _subject_url = subject_url.gsub('-', ' ')
      Asker.where('subject ilike ?', _subject_url).first
    end
  end
end
