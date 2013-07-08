class Moderation < ActiveRecord::Base
  attr_accessible :accepted, :post_id, :type_id, :user_id

  belongs_to :moderator, :class_name => 'Moderator', foreign_key: :user_id

  scope :accepted, where("accepted = ?", true)
  scope :rejected, where("accepted = ?", false)

  def accept_and_reject_moderations
    post.post_moderations.each do |moderation|
      if type_id == moderation.type_id
        moderation.update_attribute :accepted, true
        next if moderation.moderator.post_moderations.count > 1
        Post.trigger_split_test(moderation.user_id, "show moderator q & a or answer (-> accepted grade)")
      else
        moderation.update_attribute :accepted, false
      end
    end
  end
end