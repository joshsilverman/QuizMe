class SessionsController < ApplicationController
  def create
  	auth = request.env["omniauth.auth"]
    omni_params = request.env["omniauth.params"]
    provider = auth['provider']

    if omni_params['asker'] #if asker update account
      user = User.find(omni_params['asker'])
      case provider
      when 'twitter'
        user.twi_user_id = auth["uid"]
        user.twi_screen_name = auth["info"]["nickname"]
        user.twi_name = auth["info"]["name"]
        user.twi_profile_img_url = auth["extra"]["raw_info"]["profile_image_url"]
        user.twi_oauth_token = auth['credentials']['token']
        user.twi_oauth_secret = auth['credentials']['secret']
      when 'tumblr'
        user.tum_oauth_token = auth['credentials']['token']
        user.tum_oauth_secret = auth['credentials']['secret']
      when 'facebook'
        user.fb_oauth_token = auth['credentials']['token']
        user.fb_oauth_secret = auth['credentials']['secret']
      else
        puts "provider unknown: #{provider}"
      end
      user.save
      redirect_to "/askers/#{omni_params['asker']}/edit"
    else #else login with twitter
  	  user = User.find_by_provider_and_twi_user_id(auth["provider"], auth["uid"]) || User.create_with_omniauth(auth)
      session[:user_id] = user.id
      if request.env["omniauth.params"]["account_id"]
        redirect_to "/questions/new?account_id=#{request.env['omniauth.params']['account_id']}"
      else
        redirect_to root_url, :notice => "Signed in!"    
      end
    end
    
	  
  end

  def destroy
  	session[:user_id] = nil
  	redirect_to root_url, :notice => "Signed out!"
  end

end
