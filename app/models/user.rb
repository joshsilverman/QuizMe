class User < ActiveRecord::Base
	has_many :reps
	has_many :questions
	has_many :topics, :through => :askertopics
	has_many :askertopics, :foreign_key => 'asker_id'
	has_many :stats, :foreign_key => 'asker_id'
	has_many :posts
	has_many :publications, :foreign_key => 'asker_id'
	has_one :publication_queue, :foreign_key => 'asker_id'

	def publish_question
		queue = self.publication_queue
		publication = queue.publications[queue.index]
		publication.update_attribute(:published, true)
		PROVIDERS.each do |provider|
			Post.publish(provider, self, publication)
		end
		queue.increment_index(self.posts_per_day)
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
		asker = User.includes(:publications).asker(id)
		reps = Rep.where(:publication_id => asker.publications, :correct => true).select([:user_id, :id]).group_by(&:user_id).to_a.sort! {|a, b| b[1].length <=> a[1].length}[0..4]
		user_ids = reps.collect { |rep| rep[1][0][:user_id] }
		users = User.select([:twi_screen_name, :twi_profile_img_url, :id]).find(user_ids).group_by(&:id)
		reps.each { |rep| scores << {:user => users[rep[0]][0], :correct => rep[1].length} }
		data[:name] = asker.name
		data[:scores] = scores
		data
	end	

end
