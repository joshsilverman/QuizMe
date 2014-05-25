require 'test_helper'

describe RelationshipsController, "#create" do
  let(:user) { create :user }
  let(:asker) { create :asker }

  it "persists new relationship" do
    post :create, follower_id: user.id, followed_id: asker

    Relationship.count.must_equal 1
    relationship = Relationship.last
    relationship.follower_id.must_equal user.id
    relationship.followed_id.must_equal asker.id
    relationship.channel.must_equal Relationship::WISR
  end

  it "wont recreate the same relationship" do
    post :create, follower_id: user.id, followed_id: asker
    response.status.must_equal 200

    post :create, follower_id: user.id, followed_id: asker
    response.status.must_equal 200

    Relationship.count.must_equal 1
    relationship = Relationship.last
    relationship.follower_id.must_equal user.id
    relationship.followed_id.must_equal asker.id
  end

  it "allows both twitter/wisr relationships with same asker" do
    relationship = Relationship.create({
      follower_id: user.id, 
      followed_id: asker.id,
      channel: Relationship::TWITTER})

    post :create, follower_id: user.id, followed_id: asker
    response.status.must_equal 200

    Relationship.count.must_equal 2

    relationship = Relationship.first
    relationship.follower_id.must_equal user.id
    relationship.followed_id.must_equal asker.id
    relationship.channel.must_equal Relationship::TWITTER

    relationship = Relationship.last
    relationship.follower_id.must_equal user.id
    relationship.followed_id.must_equal asker.id
    relationship.channel.must_equal Relationship::WISR
  end

  it "activates an existing inactive relationship" do
    relationship = Relationship.create({
      follower_id: user.id, 
      followed_id: asker.id,
      channel: Relationship::WISR,
      active: false})

    Relationship.active.count.must_equal 0

    post :create, follower_id: user.id, followed_id: asker
    response.status.must_equal 200

    Relationship.count.must_equal 1
    Relationship.active.count.must_equal 1
  end
end

describe RelationshipsController, "#destroy" do
  let(:user) { create :user }
  let(:asker) { create :asker }

  it "deactives relationship" do
    relationship = Relationship.create({
      follower_id: user.id, 
      followed_id: asker.id,
      channel: Relationship::WISR})

    delete :destroy, id: relationship.id

    Relationship.count.must_equal 1
    Relationship.active.count.must_equal 0
  end
end