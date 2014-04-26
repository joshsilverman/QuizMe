class QuestionsTopic < ActiveRecord::Base
  belongs_to :question
  belongs_to :topic

  validates :question_id, uniqueness: {scope: :topic_id}
end