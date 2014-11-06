class Rating < ActiveRecord::Base
  belongs_to :user
  belongs_to :question

  validates :user_id, presence: true
  validates :question_id, presence: true
  validates :score, presence: true
  validates :score, inclusion: 0..5
end
