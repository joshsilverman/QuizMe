class Publication < ActiveRecord::Base
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	belongs_to :publication_queue
	belongs_to :question
	has_many :conversations
	has_many :posts

  scope :published, -> { where("publications.published = ?", true) }

  def self.find_or_create_by_question_id question_id, asker_id = nil
    publication = Publication.where(question_id: question_id).published.last

    publication ||= Publication.create(
        question_id: question_id,
        asker_id: asker_id
      )
  end

  def update_activity post
    user = post.user
    activity = self._activity || {}
    activity[user.twi_screen_name] = user.twi_profile_img_url
    self.update _activity: {} # not sure why this line is required
    self.update _activity: activity

    self
  end

  def update_question question = nil
    question ||= Question.find question_id
    return if !question.asker

    as = {}
    question.answers.each do |a|
      as[a.id.to_s] = a.text
    end

    assign_attributes(
      _question: {
        text: question.text,
        id: question.id,
        correct_answer_id: question.answers.correct.try(:id)},
      _asker: {
        id: question.asker.id,
        twi_profile_img_url: question.asker.twi_profile_img_url,
        subject: question.asker.subject,
        subject_url: question.asker.subject_url},
      _answers: as)

    save
  end

  def self.recent offset = 0
    publications = Publication.published
      .where('first_posted_at IS NOT NULL')
      .order(first_posted_at: :desc)
      .limit(10).offset(offset)
  end

  def self.recent_by_asker_json asker, injectable_id, offset = 0
    return '' if !asker

    Rails.cache.fetch("Asker.recent_by_asker_json(#{asker.id}, #{injectable_id}, #{offset})", 
      expires_in: 10.minutes) do
      
      publications = asker.publications.published
        .where('first_posted_at IS NOT NULL')
        .order(first_posted_at: :desc)
        .limit(10).offset(offset)

      if injectable_id.nil?
        publications.to_json
      else
        Publication.inject_publication_by_id(
          publications, 
          injectable_id).to_json
      end
    end
  end

  def self.inject_publication_by_id publications, injectable_id
    return publications if injectable_id.nil?

    injectable_id = injectable_id.to_s.force_encoding("UTF-8").to_i

    publication_ids = publications.collect &:id
    return publications if publication_ids.include? injectable_id

    injectable_publication = Publication.where(id: injectable_id).first
    return publications if injectable_publication.nil?

    injectable_publication.verify_cache_present

    publications.unshift injectable_publication
  end

  def verify_cache_present
    if !_answers or !_asker
      update_question
    end

    if !first_posted_at
      self.update first_posted_at: self.created_at
    end
  end
end
