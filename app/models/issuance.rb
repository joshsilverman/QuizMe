class Issuance < ActiveRecord::Base
  belongs_to :user
  belongs_to :asker
  belongs_to :badge

  validates_uniqueness_of :user_id, :scope => :badge_id
end