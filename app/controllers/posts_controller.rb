class PostsController < ApplicationController
  before_filter :admin?, :except => [:nudge_redirect, :refer, :retweet]

  def manager_retweet
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
    post.update_attribute :requires_action, false if retweet
    render :json => retweet
  end

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
      @post.moderations.each do |moderation|
        if moderation.type_id == 5
          moderation.update_attribute :accepted, true
          next if moderation.user.moderations.count > 1
          Post.trigger_split_test(moderation.user_id, 'show moderator question or answer (-> accepted grade)')
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
          @tag = Tag.find_or_create_by_name('hide-manual')
          @post.tags << @tag unless @post.tags.include? @tag
        end
      else
        format.html { render action: "edit" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end		
	end

  def toggle_tag
    post = Post.find(params[:post_id])
    tag = Tag.find_or_create_by_name(params[:tag_name])

    if post.tags.include? tag
      post.tags.delete(tag)
      render :json => false
    else
      post.tags << tag
      Mixpanel.track_event(tag.name, { :distinct_id => post.user_id }) if tag.name.include?("tutor")
      render :json => true
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
      # Post.trigger_split_test(user.id, 'ugc script v3.0')

      tag.posts << post
    end

    render :nothing => true
  end

  def tags
    @posts = Post.tagged.order("posts.created_at DESC")
    @posts = @posts.page(params[:page]).per(50)
    # params[:filter] = "week" unless params[:filter].present?

    # if params[:filter] == "week"
    #   @posts = @posts.where("posts.created_at > ?", 1.week.ago)
    # elsif params[:filter] == "month"
    #   @posts = @posts.where("posts.created_at > ?", 1.month.ago)
    # end
        
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
