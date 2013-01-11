class PostObserver < ActiveRecord::Observer

	# Observe create and update methods
  def after_create post
  	update_segments(post)
  end

  def after_update post
  	update_segments(post)
  end


  def update_segments post
  	user = post.user
  	update_lifecycle_segment(user, post)
  	update_activity_segment(user, post)
  	update_interaction_segment(user, post)
  	update_author_segment(user, post)
  end


  # Lifecycle update checks
	def update_lifecycle_segment post
	  	
	end  


	# Activity update checks
	def update_activity_segment post

	end


	# Interaction update checks
	def update_interaction_segment post

	end


	# Author update checks
	def update_author_segment	 post

	end
end