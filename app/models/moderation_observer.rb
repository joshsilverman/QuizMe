class ModerationObserver < ActiveRecord::Observer
  def after_create(moderation)
    type_id = moderation.respond_with_type_id
    if type_id
    	moderation.trigger_response

    end
  end

  def after_update(moderation)
    moderation.user.update_moderator_segment
  end
end