require 'test_helper'

describe Post, '#send_to_feed' do
  it 'calls Adapters::WisrFeed::Post with post' do
    disable_after_save
    post = FactoryGirl.create(:post)

    Adapters::WisrFeed::Post.
            expects(:save_or_update).
            with(post)

    post.send_to_feed
  end

  def disable_after_save
    PostObserver.any_instance.stubs(:after_save)
  end
end

describe Post, '.twitter_request' do
  describe 'test' do
    it 'returns empty array when passed block in test env' do
      Post.twitter_request {}.must_equal []
    end

    it 'returns empty array when passed message and block in test env' do
      Post.twitter_request('hey hey') {}.must_equal []
    end
  end

  describe 'production' do
    before :each do
      Rails.env.stubs(:test?).returns(false)
      Rails.env.stubs(:production?).returns(true)
    end

    it 'puts failure message on failure' do
      failure_message = 'message from QuizMeBio to johnnnny'

      $stdout.expects(:puts).with(includes(failure_message))
      Post.twitter_request(failure_message) { raise "error" }
    end
  end

end