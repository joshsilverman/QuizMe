class PostObserver < ActiveRecord::Observer
  def after_save post
    segment_user post
    send_to_feed post
  end

  def segment_user post
  	return if Asker.ids.include? post.user_id
    post.user.delay.segment
  end

  def send_to_feed post
    post.delay.send_to_feed
  end
end