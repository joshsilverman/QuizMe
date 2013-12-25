class PostsController < ApplicationController
  before_filter :admin?, :except => [:nudge_redirect, :refer, :retweet]

	def retweet
		return unless params[:publication_id]
		post = Publication.find(params[:publication_id]).posts.last
    retweet = Post.twitter_request { current_user.twitter.retweet(post.provider_post_id) }

    if retweet
      retweet_post = Post.create({
        :user_id => current_user.id,
        :provider => "twitter",
        :in_reply_to_post_id => post.id, 
        :in_reply_to_user_id => post.user_id,
        :posted_via_app => true, 
        :interaction_type => 3
      })

      current_user.update_user_interactions({
        :learner_level => "share", 
        :last_interaction_at => retweet_post.created_at
      })      
      
      Mixpanel.track_event "in app retweet", { :distinct_id => current_user.id }  
			render :json => retweet
		end
	end

	def update
    @post = Post.find(params[:id])
    if params[:post][:requires_action] == 'false'
      @post.post_moderations.each do |moderation|
        if moderation.type_id == 5
          moderation.update_attribute :accepted, true
          next if moderation.moderator.post_moderations.count > 1
          Post.trigger_split_test(moderation.user_id, "show moderator q & a or answer (-> accepted grade)")
        else
          moderation.update_attribute :accepted, false
        end
      end
    end

    respond_to do |format|
      if @post.update_attributes(params[:post])
        format.html { redirect_to @post, notice: 'Post was successfully updated.' }
        format.json { head :ok }

        #tag manually hidden posts
        if params['post']['requires_action'].nil? == false and params['post']['requires_action'] == "false"
          @tag = Tag.find_or_create_by(name: 'hide-manual')
          @post.tags << @tag unless @post.tags.include? @tag
        end
      else
        format.html { render action: "edit" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end		
	end

  def tags
    @posts = Post.tagged.order("posts.created_at DESC")
    @posts = @posts.page(params[:page]).per(50)
        
    @tags = Tag.all
    @engagements, @conversations = Post.grouped_as_conversations @posts

    render 'feeds/tags'
  end

  def refer
  	publication = Publication.includes(:question).find(params[:publication_id])
    if publication.question.resource_url
      redirect_to publication.question.resource_url
    else
      redirect_to "/feeds/#{publication.asker_id}"
    end
  end	

  def nudge_redirect
    nudge_type = NudgeType.find(params[:id])
    user = User.find(params[:user_id])
    nudge_type.register_conversion(user, Asker.find(params[:asker_id]))

    redirect_url = nudge_type.url
    redirect_url = redirect_url.gsub "{user_twi_screen_name}", user.twi_screen_name
    redirect_url = redirect_url.gsub "{user_id}", user.id.to_s
    redirect_to redirect_url
  end
end
