class User < ActiveRecord::Base
	has_many :reps
	has_many :engagements, :foreign_key => 'asker_id'
	has_many :questions
	has_many :topics, :through => :askertopics
	has_many :askertopics
	has_many :stats, :foreign_key => 'asker_id'
	has_many :posts, :foreign_key => 'asker_id'

	def self.create_with_omniauth(auth)
	  create! do |user|
	  	provider = auth['provider']
	    
	    case provider
	    when 'twitter'
		    user.twi_user_id = auth["uid"]
		    user.twi_screen_name = auth["info"]["nickname"]
		    user.twi_name = auth["info"]["name"]
		    user.twi_profile_img_url = auth["extra"]["raw_info"]["profile_image_url"]
		    user.twi_oauth_token = auth['credentials']['token']
				user.twi_oauth_secret = auth['credentials']['secret']
	    when 'tumblr'
		    user.tum_user_id = auth["uid"]
	    	user.tum_oauth_token = auth['credentials']['token']
				user.tum_oauth_secret = auth['credentials']['secret']
	    when 'facebook'
		    user.fb_user_id = auth["uid"]
	    	user.fb_oauth_token = auth['credentials']['token']
				user.fb_oauth_secret = auth['credentials']['secret']
	    else
	      puts "provider unknown: #{provider}"
	    end
	  end
	end

	def self.askers
		where(:role => 'asker')
	end

	def self.asker(id)
		find_by_role_and_id('asker', id)
	end

	def is_role?(role)
		self.role == role.downcase
	end

	def twitter_enabled?
		return true if self.twi_oauth_token and self.twi_oauth_secret
		return false
	end

	def tumblr_enabled?
		return true if self.tum_oauth_token and self.tum_oauth_secret
		return false
	end

	def facebook_enabled?
		return true if self.fb_oauth_token and self.fb_oauth_secret
		return false
	end

	def twitter
		if self.twitter_enabled?
			client = Twitter::Client.new(:consumer_key => SERVICES['twitter']['key'],
																 :consumer_secret => SERVICES['twitter']['secret'],
																 :oauth_token => self.twi_oauth_token,
																 :oauth_token_secret => self.twi_oauth_secret)
		end
		client
	end

	def tumblr
		if self.tumblr_enabled?
			client = Tumblife::Client.new(:consumer_key => SERVICES['tumblr']['key'],
																 :consumer_secret => SERVICES['tumblr']['secret'],
																 :oauth_token => self.tum_oauth_token,
																 :oauth_token_secret => self.tum_oauth_secret)
		end
		client
	end


	###
	### NEEDS TO BE FIXED FOR NEW USER ROLE ASKERS
	###
	# def self.get_top_scorers(id, data = {}, scores = [])
	# 	account = Account.select([:name, :id]).find(id)
	# 	posts = Post.where(:account_id => account.id).select(:id).collect(&:id)
	# 	reps = Rep.where(:post_id => posts, :correct => true).select([:user_id, :id]).group_by(&:user_id).to_a.sort! {|a, b| b[1].length <=> a[1].length}[0..9]
	# 	user_ids = reps.collect { |rep| rep[1][0][:user_id] }
	# 	users = User.select([:twi_screen_name, :id]).find(user_ids).group_by(&:id)
	# 	reps.each { |rep| scores << {:handle => users[rep[0]][0].twi_screen_name, :correct => rep[1].length} }
	# 	data[:name] = account.name
	# 	data[:scores] = scores
	# 	return data
	# end	

end
