class ModerationObserver < ActiveRecord::Observer
  def after_save(moderation)
    moderation.user.segment
  end
end