class Relationship < ActiveRecord::Base
  belongs_to :follower, :class_name => 'User'
  belongs_to :followed, :class_name => 'User'

  validates :follower_id, :presence => true
  validates :followed_id, :presence => true

  TWITTER = 0
  WISR = 1

  scope :unknown, -> { where("relationships.type_id in null") }
  scope :followback, -> { where("relationships.type_id = 1") }
  scope :search, -> { where("relationships.type_id = 2") }
  scope :organic, -> { where("relationships.type_id = 3") }
  # scope :friend_search, -> { where("type_id = 4") }
  scope :suspended, -> { where("relationships.type_id = 4") }

  scope :active, -> { where("relationships.active = ?", true) }
  scope :inactive, -> { where("relationships.active = ?", false) }

  scope :twitter, -> { where("relationships.channel = ?", TWITTER) }
  scope :wisr, -> { where("relationships.channel = ?", WISR) }
end