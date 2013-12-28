require "test_helper"

describe ModeratorTransition, "#issue_badge" do
  it "must create issuance" do
    user = User.create
    asker = Asker.create(role: 'asker')
    transition = ModeratorTransition.create(user:user, to_segment:1)
    expected_badge = Badge.create(to_segment:1, segment_type:5)

    Issuance.expects(:create).with(user:user, badge:expected_badge)
      .returns(Issuance.new)
    transition.stubs(:last_active_asker).returns(asker)

    transition.issue_badge
  end

  it "wont issuance twice" do
    user = User.create
    asker = Asker.create(role: 'asker')
    transition = ModeratorTransition.create(user:user, to_segment:1)
    expected_badge = Badge.create(to_segment:1, segment_type:5)

    transition.stubs(:last_active_asker).returns(asker)

    transition.issue_badge
    transition.issue_badge

    Issuance.count.must_equal 1
  end

  it "must notify user" do
    user = User.create
    asker = Asker.create(role: 'asker')
    post = Post.create(in_reply_to_user: asker)
    moderation = Moderation.create(post_id:post.id, user_id:user.id)
    moderation_transition = ModeratorTransition.new(user:user, to_segment:1)
    badge = Badge.create(to_segment:1, segment_type:5)

    Asker.any_instance.expects(:notify_badge_issued) #.with(user, badge)
    
    moderation_transition.issue_badge
  end

  it "wont notify user if issuance fails" do
    user = User.create
    asker = Asker.create(role: 'asker')
    post = Post.create(in_reply_to_user: asker)
    moderation = Moderation.create(post_id:post.id, user_id:user.id)
    moderation_transition = ModeratorTransition.new(user:user, to_segment:1)
    badge = Badge.create(to_segment:1, segment_type:5)

    Asker.any_instance.expects(:notify_badge_issued).with(user, badge).once

    moderation_transition.issue_badge
    moderation_transition.issue_badge
  end
end

describe ModeratorTransition, "#select_badge" do
  it "must select beginner badge if transition to segment 1" do
    user = User.create
    transition = ModeratorTransition.create(user: user, to_segment:1)
    expected_badge = Badge.create(to_segment: 1, segment_type:5)

    transition.send(:select_badge).must_equal expected_badge
  end

  it "must select regular badge if transition to segment 3" do
    user = User.create
    transition = ModeratorTransition.create(user: user, to_segment:3)
    expected_badge = Badge.create(to_segment: 3, segment_type:5)

    transition.send(:select_badge).must_equal expected_badge
  end

  it "wont select a badge with wrong segment type" do
    user = User.create
    transition = ModeratorTransition.create(user: user, to_segment:1)
    wrong_badge = Badge.create(to_segment:1, segment_type:4)

    transition.send(:select_badge).wont_equal wrong_badge
  end
end

describe ModeratorTransition, "#last_active_asker" do
  it "returns the last asker that the user moderated for" do
    moderator = Moderator.create
    asker = Asker.create(role: 'asker')
    post = Post.create(in_reply_to_user: asker)
    moderation = Moderation.create(post_id:post.id, user_id:moderator.id)
    moderation_transition = ModeratorTransition.new(user:moderator)

    moderation_transition.send(:last_active_asker).must_equal asker
  end
end