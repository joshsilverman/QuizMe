class SessionsController < ApplicationController
  def create
  	auth = request.env["omniauth.auth"]
	  user = User.find_by_provider_and_twi_user_id(auth["provider"], auth["uid"]) || User.create_with_omniauth(auth)
	  session[:user_id] = user.id
    if request.env["omniauth.params"]["account_id"]
      redirect_to "/questions/new?account_id=#{request.env['omniauth.params']['account_id']}"
    else
      redirect_to root_url, :notice => "Signed in!"    
    end
	  
  end

  def destroy
  	session[:user_id] = nil
  	redirect_to root_url, :notice => "Signed out!"
  end

end
