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