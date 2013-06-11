class AuthorizationsController < ApplicationController

  def twitter
  	oauthorize "twitter"
  end

  def facebook
  	oauthorize "facebook"
  end  

  def failure
  	redirect_to '/'
  end

  private

  	def oauthorize provider
	    if @user = find_for_ouath(provider, env["omniauth.auth"], current_user)
	      # session["devise.#{provider.downcase}_data"] = env["omniauth.auth"]
	      Mixpanel.track_event "authorized app", {:distinct_id => @user.id, :service => provider}
	      sign_in_and_redirect @user, :event => :authentication
	    end   
  	end

	  def find_for_ouath provider, auth_hash, resource
	    user, email, name, uid, auth_attr, user_attr = nil, nil, nil, {}, {}
	    case provider
	    when "twitter"
	      uid = auth_hash["uid"]
	      name = auth_hash["info"]["name"]
	      auth_attr = { 
	      	uid: uid, 
	      	token: auth_hash['credentials']['token'], 
	      	secret: auth_hash['credentials']['secret'], 
	      	name: name, 
	      	link: "http://twitter.com/#{auth_hash['info']['nickname']}" 
	      }
	      user_attr = { 
	      	twi_screen_name: auth_hash["info"]["nickname"], 
	      	name: name, 
	      	twi_name: name,
	      	twi_profile_img_url: auth_hash["extra"]["raw_info"]["profile_image_url"], 
	      	twi_oauth_token: auth_hash["credentials"]["token"], 
	      	twi_oauth_secret: auth_hash["credentials"]["secret"],
	      	twi_user_id: uid,
	      	description: auth_hash['info']['description']
	      }
	    when "facebook"
	      uid = access_token['uid']
	      email = access_token['extra']['user_hash']['email']
	      auth_attr = { :uid => uid, :token => access_token['credentials']['token'], :secret => nil, :name => access_token['extra']['user_hash']['name'], :link => access_token['extra']['user_hash']['link'] }
	    else
	      raise 'Unknown provider (#{provider})'
	    end

	    if user = resource # user is already signed in	    	
	    	if resource.is_role?('admin') and request.env["omniauth.params"]['update_asker_id'] # use proper devise roles!
	    		update_twi_asker_attributes(provider, request.env["omniauth.params"]['update_asker_id'], user_attr, auth_attr)
	    		return
	    	end
	    else
				if email # check if we have the email
					user = find_or_create_oauth_by_email(email)
				elsif uid && name # twitter doesn't provide email address, lookup by uid/name
					user = find_or_create_oauth_by_provider_and_uid(provider, uid)# || find_or_create_oauth_by_provider_and_name(provider, name)
				else
					puts 'Provider #{provider} not handled'
				end
			end

		  auth = user.authorizations.find_by_provider(provider)
		  if auth.nil?
		    auth = user.authorizations.build(:provider => provider)
		    user.authorizations << auth
		  end
		  auth.update_attributes auth_attr
		  user.update_attributes user_attr

	    user
	  end  	

	  def find_or_create_oauth_by_email email
	    unless user = User.find_by_email(email)
	      user = User.new(:email => email, :password => Devise.friendly_token[0,20]) 
	      user.save
	    end
	    user
	  end

	  # In the future, should new users w/out tokens create an authorization?
	  # Otherwise, we end up storing the uid on the User
	  def find_or_create_oauth_by_provider_and_uid provider, uid
	  	user = Authorization.find_by_uid(uid.to_s).try(:user)
	  	user = User.find_by_twi_user_id(uid) if user.blank? and provider == "twitter" # legacy support for uid on user
	    unless user
	      user = User.new(:twi_user_id => uid, :password => Devise.friendly_token[0,20])
	      user.save :validate => false
	    end
	  	user
	  end
	 
	  def find_or_create_oauth_by_provider_and_name provider, name
	  	user = Authorization.find_by_provider_and_name(provider, name).try(:user)
	  	user = User.where("twi_user_id is not null").find_by_name(name) if user.blank? and provider == "twitter"
	  	unless user
	      user = User.new(:name => name, :password => Devise.friendly_token[0,20])
	      user.save :validate => false
	    end
	    user
	  end

	  def update_twi_asker_attributes provider, asker_id, user_attr, auth_attr
	  	asker = asker_id.to_i.zero? ? Asker.new : Asker.find(asker_id.to_i)
		  auth = asker.authorizations.find_by_provider(provider)
		  if auth.nil?
		    auth = asker.authorizations.build(:provider => provider)
		    asker.authorizations << auth
		  end
		  auth.update_attributes auth_attr
		  asker.update_attributes user_attr	  	

      redirect_to "/askers/#{asker.id}/edit"
	  end
end
