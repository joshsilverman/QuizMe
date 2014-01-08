class PublicationQueue < ActiveRecord::Base
  has_many :publications
  belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	
	def self.enqueue_questions(asker)
    queue = PublicationQueue.find_or_create_by_asker_id(asker.id)
    Question.select_questions_to_post(asker, 7).each do |question_id|
      break if queue.publications.count >= asker.posts_per_day
      self.enqueue_question(asker.id, question_id)
    end
  end

  def self.enqueue_question(asker_id, question_id)
    queue = PublicationQueue.find_or_create_by(asker_id: asker_id)
    question = Question.find(question_id)

    publication = Publication.new(
      question_id: question_id,
      asker_id: asker_id, 
      publication_queue_id: queue.id,
      _cache: {
        question: question.text,
        correct_answer: question.answers.correct.try(:text)
      }
    )

    question.answers.incorrect.each_with_index do |incorrect_answer, i|
      publication._cache["incorrect_answer_#{i}"] = incorrect_answer.text
    end

    publication.save
  end

  def self.dequeue_question(asker_id, question_id)
    queue = PublicationQueue.find_or_create_by(asker_id: asker_id)
    question = Question.find question_id
    queued_pubs = question.publications.where("publication_queue_id IS NOT NULL")

    queued_pubs.each do |queued_pub|
      queued_pub.update_attribute :publication_queue_id, nil
    end
  end

  def self.clear_queue(asker)
    if asker and asker.publication_queue
      queue = asker.publication_queue
      queue.publications.where("published = ?", true).each do |pub|
        puts "Dequeue pub #{pub.id} for #{asker.twi_screen_name} and queue #{queue.id}"
        pub.update_attribute :publication_queue_id, nil
      end
      queue.update_attribute(:index, 0)
    end
  end

  def increment_index(posts_per_day)
    # puts "increment index from:"
    # puts self.index
    if self.index < (posts_per_day - 1)
      self.increment :index
    else
      self.update_attribute(:index, 0)
    end
    self.save
    # puts "to:"
    # puts self.index
  end
end
