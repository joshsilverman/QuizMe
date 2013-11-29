class SessionsController < ApplicationController

  def confirm_js
    ab_user.confirm_js(session[:user_agent], session[:remote_ip])
    render :nothing => true
  end

end
