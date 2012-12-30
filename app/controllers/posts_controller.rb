class PostsController < ApplicationController

	def retweet
		if params[:publication_id]
			post = Publication.find(params[:publication_id]).posts.last
			Post.create({
				:user_id => current_user.id,
				:provider => "twitter",
				:in_reply_to_post_id => post.id, 
				:in_reply_to_user_id => post.user_id,
				:posted_via_app => true, 
				:interaction_type => 3
			})
			render :json => current_user.twitter.retweet(post.provider_post_id)
		else
			post = Post.find(params[:post_id])
			asker = Asker.find(params[:asker_id])
			Post.create({
				:user_id => params[:asker_id],
				:provider => "twitter",
				:in_reply_to_post_id => post.id, 
				:in_reply_to_user_id => post.user_id,
				:posted_via_app => true, 
				:interaction_type => 3
			})
			render :json => asker.twitter.retweet(post.provider_post_id)			
		end
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

  def mark_ugc
    user = Post.find(params[:post_id]).user
    Post.trigger_split_test(user.id, 'ugc request type')
    Post.trigger_split_test(user.id, 'ugc script')
    render :nothing => true
  end

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
