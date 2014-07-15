class PostsController < ApplicationController
  before_filter :authenticate_user!, except: [:answer_count]
  before_filter :admin?, except: [:nudge_redirect, :refer, :retweet, :answer_count, :reengage_inactive]

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
      
      MP.track_event "in app retweet", { :distinct_id => current_user.id }  
			render :json => retweet
		end
	end

  def reengage_inactive
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

  def answer_count
    count = Post.where(user_id: params[:user_id])
      .where('correct IS NOT NULL')
      .count

    render json: count
  end
end