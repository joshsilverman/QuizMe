class Exam < ActiveRecord::Base
  attr_accessible :date, :subject, :user_id, :price, :question_count

  belongs_to :user
end
