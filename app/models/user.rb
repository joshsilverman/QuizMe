class User < ActiveRecord::Base
	has_many :reps
	has_many :questions
	has_many :askables, :class_name => 'Question', :foreign_key => 'created_for_asker_id'

	has_many :topics, :through => :askertopics
	has_many :askertopics, :foreign_key => 'asker_id'
	has_many :stats, :foreign_key => 'asker_id'
	has_many :posts
	has_many :publications, :foreign_key => 'asker_id'
	has_many :engagements, :class_name => 'Post', :foreign_key => 'in_reply_to_user_id'
	has_one :publication_queue, :foreign_key => 'asker_id'

	def publish_question
		queue = self.publication_queue
		unless queue.blank?
			puts "current queue index = #{queue.index}"
			puts "current queue order: #{queue.publications.select(:id).to_json}"
			publication = queue.publications[queue.index]
			PROVIDERS.each do |provider|
				Post.publish(provider, self, publication)
			end
			queue.increment_index(self.posts_per_day)
			puts "incremented queue index = #{queue.index}"
		end
	end

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
		self.role.include? role.downcase
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

	#here is an example of a function that cannot scale
	def self.leaderboard(id, data = {}, scores = [])
		posts = Post.select(:user_id).where(:in_reply_to_user_id => id, :correct => true).group_by(&:user_id).to_a.sort! {|a, b| b[1].length <=> a[1].length}[0..4]
		users = User.select([:twi_screen_name, :twi_profile_img_url, :id]).find(posts.collect {|post| post[0]}).group_by(&:id)
		posts.each { |post| scores << {:user => users[post[0]].first, :correct => post[1].length} }
		data[:scores] = scores
		return data
	end	

end
