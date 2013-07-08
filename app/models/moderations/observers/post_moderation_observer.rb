class PostModerationObserver < ActiveRecord::Observer
  def after_create(moderation)
    moderation.trigger_response if moderation.respond_with_type_id
  end

  def after_save(moderation)
    moderation.moderator.becomes(Moderator).update_moderator_segment
  end  
end