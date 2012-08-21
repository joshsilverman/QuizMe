class PublicationQueue < ActiveRecord::Base
  has_many :publications
  belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	
	def self.enqueue_questions(asker)
    queue = PublicationQueue.find_or_create_by_asker_id(asker.id)
    Question.select_questions_to_post(asker, 7).each do |question|
      queue.publications << Publication.create(
        :question_id => question.id,
        :asker_id => asker.id, 
        :publication_queue_id => queue.id
      )
    end
  end

  def self.clear_queue(asker)
    if asker and asker.publication_queue
      queue = asker.publication_queue
      queue.publications.destroy_all 
      queue.update_attribute(:index, 0)
    end
  end

  def increment_index(posts_per_day)
    if self.index < (posts_per_day - 1)
      self.increment :index
    else
      self.update_attribute(:index, 0)
    end
    self.save
  end
end
