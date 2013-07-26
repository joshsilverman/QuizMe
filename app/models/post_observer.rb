class PostObserver < ActiveRecord::Observer
  def after_save(post)
  	return if Asker.ids.include? post.user_id
    post.user.delay.segment
  end
end