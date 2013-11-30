require 'test_helper'

describe PostObserver, '#after_save' do
  before :all do
    ActiveRecord::Base.observers.enable :post_observer
    Delayed::Worker.delay_jobs = false
    stub_request(:post, Adapters::WisrFeed::URL)
    stub_request(:get, /mixpanel/)
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
    post = FactoryGirl.build :post

    post.expects(:send_to_feed)
    PostObserver.any_instance.stubs(:segment_user)

    post.save
  end
end

describe PostObserver, '#segment_user' do
  it "should call segment on user object" do
    user = FactoryGirl.create :user
    post = FactoryGirl.build :post, user: user

    User.any_instance.expects(:segment)

    post.save
  end

  it "wont error if post has no user" do
    post = FactoryGirl.build :post, user: nil

    User.any_instance.expects(:segment).never

    post.save
  end
end