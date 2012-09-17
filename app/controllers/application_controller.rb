class ApplicationController < ActionController::Base
  protect_from_forgery
  helper_method :current_user
  before_filter :referrer_data

  def authenticate_user
    redirect_to '/' unless current_user 
  end

  def admin?
    if current_user
      redirect_to '/' unless current_user and current_user.is_role? "admin"
    else
      redirect_to '/'
    end
  end

	private
  
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def referrer_data
    @campaign = params[:c]
    @source = params[:s]
    @link_type = params[:lt]
  end
end
