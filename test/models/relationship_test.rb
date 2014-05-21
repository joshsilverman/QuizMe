require 'test_helper'

describe Relationship do
  it "creates non-twitter relationship" do
    asker = create :asker
    user = create :user

    relationship = Relationship.create(
      follower: user,
      followed: asker,
      channel: Relationship::WISR)
  end
end