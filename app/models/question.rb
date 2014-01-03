class Question < ActiveRecord::Base
	has_many :posts
  has_many :in_reply_to_posts, :class_name => 'Post', :foreign_key => 'in_reply_to_question_id'

  has_many :answers
  has_many :publications
  has_many :question_moderations
  
  has_and_belongs_to_many :topics, -> { uniq }

  belongs_to :user
  belongs_to :asker, :foreign_key => :created_for_asker_id

  scope :not_us, -> { where('questions.user_id NOT IN (?)', Asker.all.collect(&:id) + ADMINS) }
  scope :ugc, -> { where('questions.user_id not in (?)', Asker.all.collect(&:id) + ADMINS) }

  scope :priority, -> { where('priority = ?', true) }
  scope :not_priority, -> { where('priority = ?', false) }

  scope :approved, -> { where('status = 1') }
  scope :pending, -> { where('status = 0') }
  scope :not_pending, -> { where('status != 0') }

  scope :moderated_by_consensus, -> { where(moderation_trigger_type_id: 1) }
  scope :moderated_by_above_advanced, -> { where(moderation_trigger_type_id: 2) }
  scope :moderated_by_tiebreaker, -> { where(moderation_trigger_type_id: 3) }

  before_save :generate_slug

  def lessons
    topics.where(type_id: 6)
  end

  def courses
    topics.where(type_id: 5)
  end

  def self.select_questions_to_post(asker, num_days_back_to_exclude, queue = [], priority_questions = [])
    user_grouped_priority_questions = asker.questions.approved.priority\
      .order("created_at ASC")\
      .group_by(&:user_id)

    # Sample one priority question per user
    user_grouped_priority_questions.each { |user_id, user_questions| queue << user_questions.sample.id if queue.size < asker.posts_per_day }

    # Fill queue with non-priority questions, non recent question
    if queue.size < asker.posts_per_day
      non_priority_questions = asker.questions.approved.not_priority
      
      recent_question_ids = asker.publications\
        .where("question_id is not null and published = ?", true)\
        .where("created_at > ?", num_days_back_to_exclude.days.ago)\
        .collect(&:question_id)
      recent_question_ids = [0] if recent_question_ids.blank? 

      queue += non_priority_questions.where("id not in (?)", recent_question_ids).sample(asker.posts_per_day - queue.size).collect(&:id)

      # Fill queue with recent questions
      if queue.size < asker.posts_per_day
        queue += non_priority_questions.where("id in (?)", recent_question_ids).sample(asker.posts_per_day - queue.size).collect(&:id)
      end
    end
    puts "WARNING THE QUEUE FOR #{asker.twi_screen_name} WAS NOT FULLY FILLED. ONLY #{queue.size} of #{asker.posts_per_day} POSTS SCHEDULED" if queue.size < asker.posts_per_day
    queue
  end

  def needs_feedback?
    return false if (publishable == true or inaccurate == true or ungrammatical == true or bad_answers == true or needs_edits == true)
    return true
  end

  def clear_feedback
    update(moderation_trigger_type_id: nil, publishable: nil, inaccurate: nil, ungrammatical: nil, bad_answers: nil, needs_edits: nil)
  end

  def self.unmoderated_counts
    Question.where(:status => 0).group('created_for_asker_id').count
  end

  def self.counts
    Question.group('created_for_asker_id').count
  end

  def needs_edits?
    return true if (bad_answers or inaccurate or ungrammatical)
    return false
  end

  def slug_text
    return self.text.gsub(' ', '-').gsub('&quot;', '').gsub(/[^0-9A-Za-z\-_]/, '').gsub(/-\z/, "")[0..69]
  end

  def generate_slug
    self.slug = self.slug_text if (self.slug.blank? and self.text.present?)
  end

  def correct_answer
    answers.select{|a| a.correct == true}[0] unless answers.empty?
  end

  def incorrect_answers
    answers.select{|a| a.correct != true} || []
  end

  def self.requires_moderations moderator, options = {}
    moderator = moderator.becomes(Moderator)
    is_admin = ADMINS.include?(moderator.id)

    unless is_admin
      return [] unless moderator.lifecycle_above?(3) # check if user is > regular
      return [] unless moderator.moderator_segment_above?(2) # greated than noob mod
      # return [] unless moderator.questions.approved.count > 4 # check if user has written enough questions
    end

    question_ids_moderated_by_current_user = moderator.question_moderations.collect(&:question_id)
    question_ids_moderated_by_current_user = [0] if question_ids_moderated_by_current_user.empty?    

    is_supermod = moderator.is_question_super_mod?
    requires_edit_count = is_supermod ? 2 : 0
    requires_moderation_count = is_supermod ? 3 : 5

    questions = []
    if options[:needs_edits_only] == true
      return [] unless is_admin
      questions << Question.where('moderation_trigger_type_id != 2 or moderation_trigger_type_id is null')\
        .where('needs_edits is not null or publishable is not null')\
        .order('questions.created_at DESC')
    else
      questions << Question.where('moderation_trigger_type_id != 2 or moderation_trigger_type_id is null')\
        .where('needs_edits is not null or publishable is not null')\
        .where("questions.id NOT IN (?)", question_ids_moderated_by_current_user)\
        .where("questions.user_id <> ?", moderator.id)\
        .where("questions.created_for_asker_id IN (?)", moderator.follows.where("role = 'asker'").collect(&:id))\
        .order('questions.created_at DESC')\
        .limit(requires_edit_count)
      questions << Question.where('status = 0')\
        .where('moderation_trigger_type_id is null')\
        .where('needs_edits is null and publishable is null')\
        .where("questions.user_id <> ?", moderator.id)\
        .where("questions.id NOT IN (?)", question_ids_moderated_by_current_user)\
        .where("questions.created_for_asker_id IN (?)", moderator.follows.where("role = 'asker'").collect(&:id))\
        .order('questions.created_at DESC')\
        .limit(requires_moderation_count)
    end

    questions.flatten.sort_by{|p| p.created_at}.reverse
  end

  def self.recently_published_ugc domain_start = 7, domain_end = 3
    Question.includes(:user, :in_reply_to_posts)\
      .approved\
      .where("questions.created_at > ? and questions.created_at < ?", domain_start.days.ago, domain_end.days.ago)\
      .ugc
  end

  def self.score_questions popularity_index = {}, scores = {}
    Rails.cache.fetch 'scored_questions', :expires_in => 30.minutes do
      questions_with_publication_count = Question.approved\
        .select(["questions.*", "count(publications.id) as publication_count"])\
        .joins(:publications)\
        .includes(:answers)\
        .group("questions.id")

      question_answered_counts = Post.joins("LEFT OUTER JOIN posts AS parents on parents.id = posts.in_reply_to_post_id")\
        .where("parents.interaction_type = 1")\
        .where("posts.in_reply_to_question_id is not null")\
        .answers\
        .social\
        .group("posts.in_reply_to_question_id")\
        .count 

      # build question popularity index - status answers per publication
      questions_with_publication_count.each { |q| popularity_index[q.id] = question_answered_counts[q.id].to_f / q.publication_count.to_f }

      # mark most popular 25% of questions
      popular_question_ids = popularity_index.sort_by {|k,v| v}.reverse[0..(popularity_index.size * 0.25).ceil].collect { |e| e[0] }

      # score questions / build score hash
      questions_with_publication_count.each do |q| 
        scores[q.created_for_asker_id] ||= {}
        scores[q.created_for_asker_id][q.id] = q.score(popular_question_ids.include? q.id)
      end

      scores
    end
  end

  def score is_popular, score = 0
    score += 2 if is_popular #is popular
    score += 1 if !Asker.ids.include? user_id # is ugc
    score += 1 if resource_url.present? # has resource
    score += 1 if hint.present? # has hint
    score += 1 if created_at > 2.weeks.ago # is recent
    
    message_length = TWI_MAX_SCREEN_NAME_LENGTH + 1 + text.size + 1 + TWI_SHORT_URL_LENGTH
    message_length_with_answers = TWI_MAX_SCREEN_NAME_LENGTH + 1 + text_with_answers.size + 1 + TWI_SHORT_URL_LENGTH
    score += 1 if message_length < 140 # fits into tweet
    score += 1 if message_length < 80 # is short
    score += 1 unless INCLUDE_ANSWERS.include?(id) and message_length_with_answers > 140 # unless handle should include answers, but doesn't fit
    score
  end

  def text_with_answers
    "#{text} (#{answers.shuffle.collect {|a| a.text}.join('; ')})"
  end
end