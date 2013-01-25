class PostsController < ApplicationController
  before_filter :admin?

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

      current_user.segment
      
      retweet = Post.twitter_request { current_user.twitter.retweet(post.provider_post_id) }
			render :json => retweet
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
      retweet = Post.twitter_request { asker.twitter.retweet(post.provider_post_id) }
			render :json => retweet
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
    tag = Tag.find_or_create_by_name "ugc"
    post = Post.includes(:tags).find(params[:post_id])
    post.update_attribute :intention, 'submit ugc'

    if post.tags.include? tag
      post_with_tags = Post.includes(:tags).where('tags.name = ?', tag.name).find(params[:post_id])
      post_with_tags.tags.clear
      post_with_tags.update_attribute :requires_action, false
    else
      user = post.user
      Post.trigger_split_test(user.id, 'ugc request type')
      Post.trigger_split_test(user.id, 'ugc script')

      tag.posts << post
    end

    render :nothing => true
  end

  def refer
  	publication = Publication.includes(:question).find(params[:publication_id])
    if publication.question.resource_url
      redirect_to publication.question.resource_url
    else
      redirect_to "/feeds/#{publication.user_id}"
    end
  end	

  def nudge
    nudge = NudgeType.find(params[:id])
    user = User.find(params[:user_id])
    Mixpanel.track_event "nudge conversion", {
      :distinct_id => params[:user_id],
      :asker => Asker.find(params[:asker_id]).twi_screen_name,
      :client => nudge.client.twi_screen_name
    }  
    url = nudge.url.gsub "{user_twi_screen_name}", user.twi_screen_name
    redirect_to url
  end
end
