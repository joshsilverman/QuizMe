class Question < ActiveRecord::Base
  include QuestionbaseImporter

	has_many :posts
  has_many :in_reply_to_posts, :class_name => 'Post', :foreign_key => 'in_reply_to_question_id'

  has_many :answers
  has_many :publications
  has_many :question_moderations

  has_many :topics, -> { uniq }, through: :questions_topics, :dependent => :destroy
  has_many :questions_topics, :dependent => :destroy

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
    self.text
      .gsub(' ', '-')
      .gsub('&quot;', '')
      .gsub(/[^0-9A-Za-z\-_]/, '')
      .gsub(/-\z/, "")[0..69]
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
    whitelisted_mod = WHITELISTED_MODERATORS.include?(moderator.id)

    unless is_admin || whitelisted_mod
      return [] unless moderator.lifecycle_above?(3) # check if user is > regular
      return [] unless moderator.moderator_segment_above?(2) # greated than noob mod
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
      follows_ids = moderator.follows.where("role = 'asker'").collect(&:id)
      follows_ids = Asker.published_ids if whitelisted_mod

      questions << Question.where('moderation_trigger_type_id != 2 or moderation_trigger_type_id is null')\
        .where('needs_edits is not null or publishable is not null')\
        .where("questions.id NOT IN (?)",
          question_ids_moderated_by_current_user)\
        .where("questions.user_id <> ?", moderator.id)\
        .where("questions.created_for_asker_id IN (?)", follows_ids)\
        .order('questions.created_at DESC')\
        .limit(requires_edit_count)

      questions << Question.where('status = 0')\
        .where('moderation_trigger_type_id is null')\
        .where('needs_edits is null and publishable is null')\
        .where("questions.user_id <> ?", moderator.id)\
        .where("questions.id NOT IN (?)",
          question_ids_moderated_by_current_user)\
        .where("questions.created_for_asker_id IN (?)", follows_ids)\
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

  def text_with_answers
    "#{text} (#{answers.shuffle.collect {|a| a.text}.join('; ')})"
  end

  def update_answers
    as = {}
    answers.each do |a|
      as[a.id.to_s] = a.text
    end

    assign_attributes(
      _correct_answer_id: answers.correct.try(:id),
      _answers: as)

    save
  end

  def post
    return if user.nil?
    return if user.twi_screen_name.nil?
    return if asker.nil?
    return if user.has_recently_submitted_multiple_questions(1.hour)

    msg = "New question from @#{user.twi_screen_name}: #{text}"
    url = "#{FEED_URL}/#{asker.subject_url}/#{recent_publication.id}"

    post = asker.send_public_message msg, {
      long_url: url,
      question_id: id
    }

    pub = Publication.create(
      asker: asker,
      question: self,
      published: true,
      first_posted_at: Time.now)
    pub.update_question

    if post
      pub.posts << post
    end
  end

  def recent_publication
    pub = publications.order(created_at: :desc).first
    
    if !pub
      pub = publications.create asker: asker
      pub.update_question
    end

    pub
  end

  def update_answer_counts
    update(_answer_counts: {
        correct: in_reply_to_posts.correct_answers.count('DISTINCT(posts.user_id)'),
        incorrect: in_reply_to_posts.incorrect_answers.count('DISTINCT(posts.user_id)')
      })
  end

  def send_answer_counts_to_publication
    publication = Publication.published
      .where(question_id: id)
      .order(created_at: :desc).first
    return if publication.nil?

    publication.update _answer_counts: _answer_counts
  end
end
