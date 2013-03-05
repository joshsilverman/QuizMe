class Exam < ActiveRecord::Base
  attr_accessible :date, :subject, :user_id

  belongs_to :user
end
