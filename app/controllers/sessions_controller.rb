class SessionsController < ApplicationController
  def create
  	auth = request.env["omniauth.auth"]
    omni_params = request.env["omniauth.params"]
    provider = auth['provider']

    if omni_params['update_asker_id'] #if asker update account
      user = User.asker(omni_params['update_asker_id'])
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
      redirect_to "/askers/#{omni_params['update_asker_id']}/edit"
    else #else login with twitter
  	  user = User.find_by_twi_user_id(auth["uid"]) || User.create_with_omniauth(auth)
      session[:user_id] = user.id
      if omni_params["new_question_asker_id"]
        redirect_to "/questions/new?account_id=#{omni_params['new_question_asker_id']}"
      elsif omni_params["feed_id"]
        redirect_to "/feeds/#{omni_params['feed_id']}/#{omni_params['post_id']}/#{omni_params['answer_id']}"
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
