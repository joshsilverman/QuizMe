class ModerationObserver < ActiveRecord::Observer
  def after_create(moderation)
    moderation.trigger_response if moderation.respond_with_type_id
  end

  def after_update(moderation)
    moderation.user.becomes(Moderator).update_moderator_segment
  end
end