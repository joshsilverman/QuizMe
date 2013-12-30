require 'test_helper'

describe Transition, "TransitionObserver#after_create" do
  it "must be called after a new transition is created" do
    ActiveRecord::Base.observers.enable :transition_observer

    transition = Transition.new
    TransitionObserver.any_instance.expects(:after_create).with(transition)
    transition.save
  end

  # it "must call transition.issue_badge " do
  #   transition = Transition.create(segment_type: 5)
  #   Transition.any_instance.expects(:issue_badge)

  #   TransitionObserver.send(:new).after_create(transition)
  # end

  it "wont call transition.issue_badge " do
    transition = Transition.create(segment_type: 5)
    Transition.any_instance.expects(:issue_badge).never

    TransitionObserver.send(:new).after_create(transition)
  end
end