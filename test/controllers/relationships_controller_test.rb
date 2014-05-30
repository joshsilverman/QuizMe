require 'test_helper'

describe RelationshipsController, "#create" do
  let(:user) { create :user }
  let(:asker) { create :asker }

  it "persists new relationship" do
    sign_in user
    post :create, followed_id: asker.id
    response.status.must_equal 200

    Relationship.count.must_equal 1
    relationship = Relationship.last
    relationship.follower_id.must_equal user.id
    relationship.followed_id.must_equal asker.id
    relationship.channel.must_equal Relationship::WISR
  end

  it "wont recreate the same relationship" do
    sign_in user
    post :create, followed_id: asker
    response.status.must_equal 200

    post :create, followed_id: asker
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

    sign_in user
    post :create, followed_id: asker
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

    sign_in user
    post :create, followed_id: asker
    response.status.must_equal 200

    Relationship.count.must_equal 1
    Relationship.first.wisr?.must_equal true
    Relationship.active.count.must_equal 1
  end

  it "responds with redirect if not authenticated" do
    post :create, follower_id: user.id, followed_id: asker

    Relationship.count.must_equal 0
    response.status.must_equal 302
  end

  it "always sets the follower to current_user" do
    sign_in user
    post :create, follower_id: 123, followed_id: asker.id

    Relationship.count.must_equal 1
    relationship = Relationship.last
    relationship.follower_id.must_equal user.id
    relationship.followed_id.must_equal asker.id
    relationship.channel.must_equal Relationship::WISR
  end
end

describe RelationshipsController, "#destroy" do
  let(:user) { create :user }
  let(:asker) { create :asker }

  it "responds with redirect if not authenticated" do
    relationship = Relationship.create({
      follower_id: user.id, 
      followed_id: asker.id,
      channel: Relationship::WISR})

    post :deactivate, followed_id: relationship.followed_id

    response.status.must_equal 302
  end

  it "deactives relationship" do
    relationship = Relationship.create({
      follower_id: user.id, 
      followed_id: asker.id,
      channel: Relationship::WISR})

    sign_in user
    post :deactivate, followed_id: relationship.followed_id

    Relationship.count.must_equal 1
    Relationship.active.count.must_equal 0
  end

  it "wont deactivate relationship where current user not follower" do
    relationship = Relationship.create({
      follower_id: 123, 
      followed_id: asker.id,
      channel: Relationship::WISR})

    sign_in user
    post :deactivate, followed_id: relationship.followed_id

    Relationship.count.must_equal 1
    Relationship.active.count.must_equal 1
  end

  it "wont deactivate relationship through twitter channel" do
    relationship = Relationship.create({
      follower_id: user.id, 
      followed_id: asker.id,
      channel: Relationship::TWITTER})

    sign_in user
    post :deactivate, followed_id: relationship.followed_id
    response.status.must_equal 400

    Relationship.count.must_equal 1
    Relationship.first.twitter?.must_equal true
    Relationship.active.count.must_equal 1
  end
end