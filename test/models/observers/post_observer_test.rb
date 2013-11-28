require 'test_helper'

describe PostObserver, '#after_save' do
  it "should call send_to_feed with post" do
    post = FactoryGirl.build :post

    PostObserver.any_instance.expects(:send_to_feed).with(post)

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