class PostObserver < ActiveRecord::Observer
  def after_save post
    segment_user post
    send_to_feed post
    send_to_stream post
    send_to_publication post
  end

  def segment_user post
  	return if Asker.ids.include? post.user_id
    return if post.user.nil?

    post.user.delay.segment
  end

  def send_to_feed post
    post.delay.send_to_feed
  end

  def send_to_stream post
    return if post.in_reply_to_question_id.nil?
    return unless post.intention == 'respond to question'

    post.send_to_stream
  end

  def send_to_publication post
    post.delay.send_to_publication
  end
end