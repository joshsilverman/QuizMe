class UsersController < ApplicationController
  before_filter :admin?, :except => [:questions, :unsubscribe, :unsubscribe_form, :asker_questions, :activity, :activity_feed, :add_email]

  def activity_feed
    @activity = current_user.activity(since: 1.month.ago)
    render :partial => 'activity_feed'  
  end

  def activity
    @user = User.find(params[:id])
    @activity = @user.activity(since: 1.month.ago)
    @subscribed = Asker.includes(:related_askers).where("id in (?)", @user.follows.collect(&:id))
  end

  def add_email
    if status = current_user.update(email: params[:email])
      Post.trigger_split_test(current_user.id, 'request email after answer script (provides email address)')
    end
    
    render :json => status
  end

  def unsubscribe_form
    @user = User.find(params[:id])
  end

  def unsubscribe
    user = User.find(params[:user_id])
    user.update_attribute :subscribed, false if user.email.downcase == params[:email].downcase
    render :json => user.subscribed
  end
end