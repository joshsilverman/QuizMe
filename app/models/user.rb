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

  def self.reengage_inactive_users(threshold = 1.week.ago)
    ## COLLECT DISENGAGING USERS
    all_asker_ids = User.askers.collect(&:id)
    puts all_asker_ids.to_json
    user_ids = []
    all_posts = Post.not_spam.where("(created_at > ? and created_at < ? and correct is not null) or (created_at > ? and intention = ?)", (threshold - 1.week).beginning_of_day, threshold.end_of_day, threshold.end_of_day, 'reengage last week inactive')
    all_posts.group_by(&:user_id).each do |user_id, posts|
      user_ids << user_id unless all_asker_ids.include? user_id or all_posts.where(:intention => 'reengage last week inactive', :in_reply_to_user_id => user_id).present?
    end
    engaged_user_ids = Post.not_spam.where("created_at > ? and user_id in (?)", threshold.end_of_day, user_ids).collect(&:user_id).uniq! || []
    disengaging_user_ids = user_ids - engaged_user_ids

    ## GET POPULAR PUBLICATIONS
    askers_users = {}
    askers_publications = {}
    active_asker_ids = []
    user_grouped_posts = all_posts.group_by(&:user_id)
    disengaging_user_ids.each do |user_id|
      asker_id = user_grouped_posts[user_id].sample.in_reply_to_user_id
      active_asker_ids << asker_id
      askers_users[asker_id] = [] if askers_users[asker_id].nil?
      askers_users[asker_id] << user_id
    end
    Post.includes(:conversations).where("user_id in (?) and created_at > ? and interaction_type = 1", active_asker_ids, 1.week.ago).group_by(&:user_id).each do |user_id, posts|
      askers_publications[user_id] = posts.sort_by{|p| p.conversations.size}.last.publication_id
    end

    ## TWEET POPULAR PUBS TO DISENGAGING USERS
    users = User.find(active_asker_ids + disengaging_user_ids).group_by(&:id)
    publications = Publication.includes(:question).find(askers_publications.values).group_by(&:id)
    askers_publications.each do |asker_id, publication_id|
      asker = users[asker_id][0]
      puts "#{asker.twi_screen_name} sending question: "
      puts "#{publications[publication_id][0].question.text} "
      puts "to user(s):"
      next unless asker.is_role? "asker"
      askers_users[asker_id].each do |user_id|
        puts users[user_id][0].twi_screen_name
        option_text = Post.create_split_test(user_id, "reengage last week inactive", "Pop quiz:", "We've missed you!")
        Post.tweet(asker, "#{option_text} #{publications[publication_id][0].question.text}", {
          :reply_to => users[user_id][0].twi_screen_name,
          :long_url => "http://wisr.com/feeds/#{asker.id}/#{publication_id}",
          :in_reply_to_user_id => user_id,
          :posted_via_app => true,
          :publication_id => publication_id,  
          :requires_action => false,
          :interaction_type => 2,
          :link_to_parent => false,
          :link_type => "reengage",
          :intention => "reengage last week inactive"
        })  
				Mixpanel.track_event "reengage last week inactive", {:distinct_id => users[user_id][0].id}
        sleep(1)
      end
      puts "\n"
    end
  end

 	def self.reengage_incorrect_answerers
    askers = User.askers
    current_time = Time.now
    range_begin = 24.hours.ago
    range_end = 23.hours.ago
    
    puts "Current time: #{current_time}"
    puts "range = #{range_begin} - #{range_end}"
    
    recent_posts = Post.where("user_id is not null and ((correct = ? and created_at > ? and created_at < ? and interaction_type = 2) or (intention = ? and created_at > ?))", false, range_begin, range_end, 'reengage', range_end).includes(:user)
    user_grouped_posts = recent_posts.group_by(&:user_id)
    asker_ids = askers.collect(&:id)
    user_grouped_posts.each do |user_id, posts|
      # should ensure only one tweet per user as well here?
      next if asker_ids.include? user_id or recent_posts.where(:intention => 'reengage', :in_reply_to_user_id => user_id).present?
      incorrect_post = posts.sample
      # eww, think we need a cleaner way to access the question associated w/ a post
      question = incorrect_post.conversation.publication.question
      asker = User.askers.find(incorrect_post.in_reply_to_user_id)
      if Post.create_split_test(user_id, "mention reengagement", "response follow-up", "re-ask question") == "re-ask question"
        text = "Try this one again: #{question.text}"       
        link = false
      else 
        text = "Quick follow up... you missed this one yesterday, do you know it now?"
        link = true
      end
      # always link? another A/B test?
      # existing re-engages should be changed to follow-up!!!
      Post.tweet(asker, text, {
        :reply_to => incorrect_post.user.twi_screen_name,
        :long_url => "http://wisr.com/questions/#{question.id}/#{question.slug}",
        :in_reply_to_post_id => incorrect_post.id,
        :in_reply_to_user_id => user_id,
        :conversation_id => incorrect_post.conversation_id,
        :posted_via_app => true, 
        :requires_action => false,
        :interaction_type => 2,
        :link_to_parent => link,
        :link_type => "follow_up",
        :intention => "incorrect answer follow up"
      })  
			Mixpanel.track_event "incorrect answer follow up sent", {:distinct_id => user_id}
      puts "sending follow-up message to: #{user_id}"
      sleep(1)
    end
    puts "\n"       
  end
end
