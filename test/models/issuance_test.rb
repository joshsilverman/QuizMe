require "test_helper"

describe Issuance, "#batch_back_issue_moderation_badges" do
  it "should issue new born mod badge to moderator level 1" do
    moderator = create :moderator, moderator_segment: 1
    asker = create :asker
    post = moderator.posts.create in_reply_to_user_id: asker.id
    moderation = moderator.moderations.create post_id: post.id
    badge = Badge.create to_segment: 1, segment_type: 5

    Issuance.batch_back_issue_moderation_badges

    Issuance.count.must_equal 1
    Issuance.first.user_id.must_equal moderator.id
    Issuance.first.badge_id.must_equal badge.id
    Issuance.first.asker_id.must_equal asker.id
  end

  it "wont reissue a badge" do
    moderator = create :moderator, moderator_segment: 1
    asker = create :asker
    post = moderator.posts.create in_reply_to_user_id: asker.id
    moderation = moderator.moderations.create post_id: post.id
    badge = Badge.create to_segment: 1, segment_type: 5
    issuance = Issuance.create asker: asker, user: moderator, badge: badge

    Issuance.batch_back_issue_moderation_badges

    Issuance.count.must_equal 1
  end

  it "should issue 5 badges if level 5 with no previous badges" do
    moderator = create :moderator, moderator_segment: 5
    asker = create :asker
    post = moderator.posts.create in_reply_to_user_id: asker.id
    moderation = moderator.moderations.create post_id: post.id
    badge_1 = Badge.create to_segment: 1, segment_type: 5
    badge_2 = Badge.create to_segment: 2, segment_type: 5
    badge_3 = Badge.create to_segment: 3, segment_type: 5
    badge_4 = Badge.create to_segment: 4, segment_type: 5
    badge_5 = Badge.create to_segment: 5, segment_type: 5

    Issuance.batch_back_issue_moderation_badges

    issuances = Issuance.all
    issuances.reject { |i| i.user_id != moderator.id }.count.must_equal 5

    issuances.select { |i| i.badge == badge_1 }.count.must_equal 1
    issuances.select { |i| i.badge == badge_2 }.count.must_equal 1
    issuances.select { |i| i.badge == badge_3 }.count.must_equal 1
    issuances.select { |i| i.badge == badge_4 }.count.must_equal 1
    issuances.select { |i| i.badge == badge_5 }.count.must_equal 1
  end

  it "wont issue a badge if no post moderation" do
    moderator = create :moderator, moderator_segment: 1
    asker = create :asker
    moderation = moderator.moderations.create
    badge = Badge.create to_segment: 1, segment_type: 5

    Issuance.batch_back_issue_moderation_badges

    Issuance.count.must_equal 0
  end

  it "wont issue a badge if post moderation exists but last moderation was for question" do
    moderator = create :moderator, moderator_segment: 1
    asker = create :asker
    post = moderator.posts.create in_reply_to_user_id: asker.id
    moderation = moderator.moderations.create post_id: post.id
    moderation = moderator.moderations.create
    badge = Badge.create to_segment: 1, segment_type: 5

    Issuance.batch_back_issue_moderation_badges

    Issuance.count.must_equal 1
  end
end