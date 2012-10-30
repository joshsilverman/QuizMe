class SessionsController < ApplicationController
  def create
  	auth = request.env["omniauth.auth"]
    omni_params = request.env["omniauth.params"]
    provider = auth['provider']

    if current_user and current_user.is_role?('admin') and omni_params['update_asker_id'] #if asker update account

      user = User.asker(omni_params['update_asker_id'])
      puts user
      user ||= User.find_by_twi_user_id auth["uid"]
      puts user.to_yaml
      user ||= User.new
      user.role = 'asker'
      puts user

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
      redirect_to "/askers/#{user.id}/edit"

    else #else login with twitter

  	  user = User.find_by_twi_user_id(auth["uid"]) || User.create_with_omniauth(auth)
      user.update_attributes(
        :twi_screen_name => auth["info"]["nickname"], 
        :twi_name => auth["info"]["name"],
        :twi_profile_img_url => auth["extra"]["raw_info"]["profile_image_url"],
        :twi_oauth_token => auth["credentials"]["token"],
        :twi_oauth_secret => auth["credentials"]["secret"]
      )
      session[:user_id] = user.id
      #temporary fix until devise
      # cookies.permanent.signed[:permanent_user_id] = user.id
      if omni_params["question_id"]
        redirect_to "/questions/#{omni_params['question_id']}/#{omni_params['answer_id']}"
      elsif omni_params["feed_id"]
        if omni_params['feed_id'] == "1"
          redirect_to "/feeds/index/#{omni_params['post_id']}/#{omni_params['answer_id']}"
        else
          redirect_to "/feeds/#{omni_params['feed_id']}/#{omni_params['post_id']}/#{omni_params['answer_id']}"
        end
      else
        redirect_to root_url, :notice => "Signed in!"    
      end
    end
  end

  def destroy
  	session[:user_id] = nil
    #temporary fix until devise
    cookies.delete :permanent_user_id
  	redirect_to root_url, :notice => "Signed out!"
  end

  def confirm_js
    puts "CONFIRM JS"
    puts session[:user_agent]
    puts session[:remote_ip]
    puts "done"
    ab_user.confirm_js(session[:user_agent], session[:remote_ip])
    render :nothing => true
  end

end
