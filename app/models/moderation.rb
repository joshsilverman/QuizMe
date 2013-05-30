class Moderation < ActiveRecord::Base
  attr_accessible :accepted, :post_id, :type_id, :user_id

  belongs_to :user
  belongs_to :post

  scope :correct, where(type_id: 1)
  scope :incorrect, where(type_id: 2)
  scope :tell, where(type_id: 3)
  # scope :hide, where(type_id: 4)
  scope :ignore, where(type_id: 5)
  scope :requires_detailed, where(type_id: 6)
end
