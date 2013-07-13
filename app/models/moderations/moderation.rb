class Moderation < ActiveRecord::Base
  attr_accessible :accepted, :post_id, :type_id, :user_id, :question_id

  belongs_to :moderator, :class_name => 'Moderator', foreign_key: :user_id

  scope :accepted, -> { where("accepted = ?", true) }
  scope :rejected, -> { where("accepted = ?", false) }
end