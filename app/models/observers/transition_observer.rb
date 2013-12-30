class TransitionObserver < ActiveRecord::Observer
  def after_create(transition)
    # transition.issue_badge
  end
end