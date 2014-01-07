class Issuance < ActiveRecord::Base
  belongs_to :user
  belongs_to :asker
  belongs_to :badge

  validates_uniqueness_of :user_id, :scope => :badge_id

  def self.batch_back_issue_moderation_badges
    users = Moderator.joins(post_moderations: [:post]).group('users.id')
    users.each do |user| 
      self.back_issue_moderation_badge user
    end
  end

  def self.back_issue_moderation_badge moderator
    current_segment = moderator.moderator_segment
    return if current_segment.nil?

    asker_id = moderator.post_moderations.last.post.in_reply_to_user_id
    asker = Asker.find asker_id

    (1..current_segment).each do |segment|
      badge = Badge.where(to_segment: segment, segment_type: 5).first

      Issuance.where(asker: asker, user: moderator, badge: badge)
        .first_or_create
    end
  end
end