class UpdatePublicationCache < ActiveRecord::Migration
  def up
    Publication.published.
      where('created_at > ?', 7.days.ago).each do |publication|
      question = publication.question

      if question and publication
        publication.update_question question
      end 
    end
  end
end
