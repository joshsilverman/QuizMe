require 'test_helper'

describe Transition, "#issue_badge" do
  it "must call moderator_transition.issue_badge if type moderator" do
    transition = Transition.create(segment_type: 5)
    ModeratorTransition.any_instance.expects(:issue_badge)
    
    transition.issue_badge
  end

  it "wont call moderator_transition.issue_badge if not type moderator" do
    transition = Transition.create(segment_type: 4)
    ModeratorTransition.any_instance.expects(:issue_badge).never
    
    transition.issue_badge
  end

  it 'must call lifecycle_transition.issue_badge if type lifecyle' do
    transition = Transition.create(segment_type: 1)
    LifecycleTransition.any_instance.expects(:issue_badge)
    
    transition.issue_badge
  end

  it 'wont call lifecycle_transition.issue_badge if not type lifecyle' do
    transition = Transition.create(segment_type: 22)
    LifecycleTransition.any_instance.expects(:issue_badge).never
    
    transition.issue_badge
  end
end