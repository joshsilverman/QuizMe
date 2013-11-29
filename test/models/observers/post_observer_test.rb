require 'test_helper'

describe PostObserver, '#after_save' do
  before :all do
    ActiveRecord::Base.observers.enable :post_observer
  end

  it "should call send_to_feed with post" do
    post = FactoryGirl.build :post

    PostObserver.any_instance.expects(:send_to_feed).with(post)

    post.save
  end

  it "should call segment_user with post" do
    post = FactoryGirl.build :post

    PostObserver.any_instance.expects(:segment_user).with(post)

    post.save
  end
end

describe PostObserver, '#send_to_feed' do
  it "should call send_to_feed on post object" do
    post = FactoryGirl.create :post

    post.expects(:send_to_feed)
    Delayed::Worker.delay_jobs = false

    PostObserver.send(:new).send_to_feed(post)
  end
end

describe PostObserver, '#segment_user' do
  it "should call segment on user object" do
    user = FactoryGirl.create :user
    post = FactoryGirl.create :post, user: user

    User.any_instance.expects(:segment)
    Delayed::Worker.delay_jobs = false

    PostObserver.send(:new).segment_user(post)
  end

  it "wont error if post has no user" do
    post = FactoryGirl.create :post, user: nil

    User.any_instance.expects(:segment).never
    Delayed::Worker.delay_jobs = false

    PostObserver.send(:new).segment_user(post)
  end
end