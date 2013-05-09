class Relationship < ActiveRecord::Base
  attr_accessible :followed_id

  belongs_to :follower, :class_name => 'User'
  belongs_to :followed, :class_name => 'User'

  validates :follower_id, :presence => true
  validates :followed_id, :presence => true

  scope :unknown, where("type_id in null")
  scope :followback, where("type_id = 1")
  scope :search, where("type_id = 2")
  # scope :friend_search, where("type_id = 3")
  
end