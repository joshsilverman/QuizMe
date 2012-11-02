class PostsController < ApplicationController
	
	def update_engagement_type
		post = Post.find(params[:id])
		puts params[:engagement_type]
		puts post.engagement_type
		# post.update_attribute(:engagement_type, params[:engagement_type])

    # Stat.update_stat_cache("retweets", 1, current_acct, post.created_at, u.id)
    # Stat.update_stat_cache("active_users", u.id, current_acct, post.created_at, u.id)		
    # Stat.update_stat_cache("questions_answered", 1, asker, user_post.created_at, current_user.id)
    # Stat.update_stat_cache("internal_answers", 1, asker, user_post.created_at, current_user.id)
    # Stat.update_stat_cache("active_users", current_user.id, asker, user_post.created_at, current_user.id)

		render :nothing => true
	end

	def retweet
		render :json => current_user.twitter.retweet(Publication.find(params[:publication_id]).posts.last.provider_post_id)
	end

	def update
    @post = Post.find(params[:id])

    respond_to do |format|
      if @post.update_attributes(params[:post])
        format.html { redirect_to @post, notice: 'Post was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end		
	end

	# def update
	# 	puts 'UPDATE'
	# 	eng = Post.find(params[:post_id])
	# 	correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
	# 	eng.update_responded(correct) if eng
	# 	render :nothing => true
	# end

	# def respond_to_post
	# 	post = Post.find(params[:post_id].to_i)
	# 	correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
	# 	unless correct.nil? or post.nil?
 #      asker = User.asker(params[:asker_id].to_i)
 #      user = post.user
 #      conversation = post.conversation
 #      question_id = conversation.publication.question_id
 #      post.update_responded(correct, conversation.publication_id, question_id, asker.id)
 #      tweet = post.generate_response(params[:response_type])
	# 		if params[:response_type] == 'fast'
	# 			puts 'fast'
	# 			Post.tweet(asker, tweet, '','',"#{URL}/feeds/#{asker.id}/#{conversation.publication_id}", 2, conversation.id, nil, post.id, user.id, false)
	# 		else
	# 			puts 'others'
	# 			Post.tweet(asker, tweet, '',user.twi_screen_name,"#{URL}/feeds/#{asker.id}/#{conversation.publication_id}", 2, "#{correct ? 'cor' : 'inc'}", conversation.id, nil, post.id, user.id, false)
	# 		end
	# 		render :nothing => true, :status => 200
	# 	else
	# 		post.update_attribute(:requires_action, false)
	# 		render :nothing => true, :status => 200
	# 	end
	# end

  def refer
  	post = Post.includes(:publication => :question).find(params[:id])
    if post.publication.question.resource_url
      Stat.update_stat_cache("click_throughs", 1, post.user_id, Date.today, (current_user ? current_user.id : nil))
      redirect_to post.publication.question.resource_url
    else
      redirect_to "/feeds/#{post.user_id}"
    end
  end	

  def get_shortened_link
  	unless url = Rails.cache.read("short_url:#{params[:intent]}:question:#{params[:question_id]}")
  		question = Question.find(params[:question_id])
  		url = Post.shorten_url("http://wisr.com/questions/#{question.id}/#{question.slug}", params[:provider], params[:intent], params[:asker_name])
  		Rails.cache.write("short_url:#{params[:intent]}:question:#{params[:question_id]}", url)
  	end
  	render :text => url
  end
end
