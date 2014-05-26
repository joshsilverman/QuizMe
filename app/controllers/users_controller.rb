class UsersController < ApplicationController
  before_filter :admin?, :except => [:questions, :unsubscribe, :unsubscribe_form, :asker_questions, :activity, :activity_feed, :correct_question_ids, :wisr_follow_ids]
  before_filter :authenticate_user!, :only => [:correct_question_ids, :wisr_follow_ids]

  def activity_feed
    @activity = current_user.activity(since: 1.month.ago)
    render :partial => 'activity_feed'  
  end

  def activity
    @user = User.find(params[:id])
    @activity = @user.activity(since: 1.month.ago)
    @subscribed = Asker.includes(:related_askers).where("id in (?)", @user.follows.collect(&:id))
  end

  def unsubscribe_form
    @user = User.find(params[:id])
  end

  def unsubscribe
    user = User.find(params[:user_id])
    user.update_attribute :subscribed, false if user.email.downcase == params[:email].downcase
    render :json => user.subscribed
  end

  def correct_question_ids
    respond_to do |format|
      format.json do
        user = User.find params[:user_id]
        correct_question_ids = user.posts
          .where(correct: true).where('in_reply_to_question_id IS NOT NULL')
          .pluck(:in_reply_to_question_id)

        render json: correct_question_ids.to_json
      end
    end
  end

  def wisr_follow_ids
    user = User.find(params[:user_id])

    respond_to do |format|
      format.json do
        ids = Relationship.active
          .where({follower_id: user.id, 
            channel: Relationship::WISR})
          .pluck(:followed_id)

        render json: ids.to_json
      end
    end
  end
end