require 'test_helper'

describe Publication, '#update_activity' do
  it "must set activity and twi profile image on publication" do
    user = create :user
    post = Post.create user: user
    publication = Publication.create

    publication = publication.update_activity post

    publication._activity[user.twi_screen_name]
      .must_equal user.twi_profile_img_url
  end

  it "must allow activity for multiple users" do
    user1 = create :user
    post1 = Post.create user: user1

    user2 = create :user, twi_screen_name: '1', twi_profile_img_url: 'b.jpg'
    post2 = Post.create user: user2

    publication = Publication.create

    publication = publication.update_activity post1
    publication = publication.update_activity post2

    publication._activity.keys.count.must_equal 2
    publication._activity[user1.twi_screen_name]
      .must_equal user1.twi_profile_img_url
    publication._activity[user2.twi_screen_name]
      .must_equal user2.twi_profile_img_url
  end
end