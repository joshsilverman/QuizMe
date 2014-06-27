require 'test_helper'

describe Post, 'PostObserver#after_save' do
  before :all do
    ActiveRecord::Base.observers.enable :post_observer
    Delayed::Worker.delay_jobs = false
    stub_request(:get, /mixpanel/)
  end

  it "should call send_to_stream with post" do
    post = FactoryGirl.build :post

    PostObserver.any_instance.stubs(:segment_user)
    PostObserver.any_instance.stubs(:send_to_publication)
    PostObserver.any_instance.expects(:send_to_stream).with(post)

    post.save
  end

  it "should call segment_user with post" do
    post = FactoryGirl.build :post

    PostObserver.any_instance.stubs(:send_to_stream)
    PostObserver.any_instance.stubs(:send_to_publication)
    PostObserver.any_instance.expects(:segment_user).with(post)

    post.save
  end

  it "should call send_to_publication with post" do
    post = FactoryGirl.build :post

    PostObserver.any_instance.stubs(:send_to_stream)
    PostObserver.any_instance.stubs(:segment_user)
    PostObserver.any_instance.expects(:send_to_publication).with(post)

    post.save
  end

  it "should call send_to_publication with post after update too" do
    post = FactoryGirl.build :post

    PostObserver.any_instance.stubs(:send_to_stream)
    PostObserver.any_instance.stubs(:segment_user)
    PostObserver.any_instance.expects(:send_to_publication).with(post).twice

    post.save
    post.update text: 'hoot!'
  end
end

describe Post, 'PostObserver#send_to_stream' do
  it "should call send_to_stream on post mention with in_reply_to_question" do
    post = FactoryGirl.create :post
    post.update in_reply_to_question_id: 123,
      intention: 'respond to question'

    post.expects(:send_to_stream)

    PostObserver.send(:new).send_to_stream post
  end

  it "should call send_to_stream if post is private but answers a question" do
    post = FactoryGirl.create :dm,
      in_reply_to_question_id: 123,
      intention: 'respond to question'

    post.expects(:send_to_stream).once

    PostObserver.send(:new).send_to_stream post
  end

  it "wont call send_to_stream if post is not in reply to a question" do
    post = FactoryGirl.create :post
    post.update in_reply_to_question: nil

    post.expects(:send_to_stream).never

    PostObserver.send(:new).send_to_stream post
  end

  it "wont call send_to_stream if intention not correct" do
    post = FactoryGirl.create :post
    post.update in_reply_to_question_id: 123,
      intention: 'asdf'

    post.expects(:send_to_stream).never

    PostObserver.send(:new).send_to_stream post
  end

  it "wont call send_to_stream if answer not correct" do
    post = FactoryGirl.create :post
    post.update in_reply_to_question_id: 123,
      intention: 'respond to question',
      correct: false

    post.expects(:send_to_stream).never

    PostObserver.send(:new).send_to_stream post
  end

  it "will call send_to_stream if twi_screen_name" do
    user = create :user, twi_screen_name: 'joey'
    post = FactoryGirl.create :post
    post.update in_reply_to_question_id: 123,
      intention: 'respond to question'

    post.expects(:send_to_stream)

    PostObserver.send(:new).send_to_stream post
  end

  it "wont call send_to_stream if no twi_screen_name" do
    user = create :user, twi_screen_name: nil
    post = FactoryGirl.create :post, user: user
    post.update in_reply_to_question_id: 123,
      intention: 'respond to question'

    post.expects(:send_to_stream).never

    PostObserver.send(:new).send_to_stream post
  end

  it "wont call send_to_stream if no user" do
    post = FactoryGirl.create :post, user: nil
    post.update in_reply_to_question_id: 123,
      intention: 'respond to question'

    post.expects(:send_to_stream).never

    PostObserver.send(:new).send_to_stream post
  end
end

describe Post, 'PostObserver#segment_user' do
  before :all do
    ActiveRecord::Base.observers.enable :post_observer
  end

  it "should call segment on user object" do
    user = FactoryGirl.create :user
    post = FactoryGirl.build :post, user: user

    User.any_instance.expects(:segment)
    PostObserver.any_instance.stubs(:send_to_stream)
    PostObserver.any_instance.stubs(:send_to_publication)

    post.save
  end

  it "wont error if post has no user" do
    post = FactoryGirl.build :post, user: nil

    User.any_instance.expects(:segment).never
    PostObserver.any_instance.stubs(:send_to_stream)
    PostObserver.any_instance.stubs(:send_to_publication)

    post.save
  end
end

describe Post, 'PostObserver#send_to_publication' do
  it "should call send_to_publication on post object" do
    post = FactoryGirl.create :post

    post.expects(:send_to_publication)

    PostObserver.send(:new).send_to_publication post
  end
end