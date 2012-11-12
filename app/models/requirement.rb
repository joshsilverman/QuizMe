class Requirement < ActiveRecord::Base
  belongs_to :badge
  belongs_to :question
end
