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

  has_many :badges, :through => :issuances, :uniq => true
  has_many :issuances

  has_many :relationships, :foreign_key => :follower_id, :dependent => :destroy
  has_many :follows, :through => :relationships, :source => :followed

  has_many :reverse_relationships, :foreign_key => :followed_id, :class_name => 'Relationship', :dependent => :destroy
  has_many :followers, :through => :reverse_relationships, :source => :follower
  
  scope :not_spam_with_posts, joins(:posts)\
    .where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)\
    .where("role in ('user','author')")\

  scope :social_not_spam_with_posts, joins(:posts)\
    .where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)\
    .where("role in ('user','author')")\
    .where('interaction_type IN (2,3)')\

	def publish_question
		queue = self.publication_queue
		unless queue.blank?
			# puts "current queue index = #{queue.index}"
			puts "current queue order: #{queue.publications.select(:id).to_json}"
			publication = queue.publications.order(:id)[queue.index]
			PROVIDERS.each do |provider|
				Post.publish(provider, self, publication)
			end
			queue.increment_index(self.posts_per_day)
			# puts "incremented queue index = #{queue.index}"
		end
	end

	def update_user_interactions(params = {})
		if params[:learner_level]
			params.delete :learner_level unless LEARNER_LEVELS.index(params[:learner_level]) > LEARNER_LEVELS.index(self.learner_level)
		end
		if params[:last_interaction_at]
			params.delete :last_interaction_at unless self.last_interaction_at.blank? or params[:last_interaction_at] > self.last_interaction_at
		end
		if params[:last_answer_at]
			params.delete :last_answer_at unless self.last_answer_at.blank? or params[:last_answer_at] > self.last_answer_at
		end
		self.update_attributes params	
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

	def self.engage_new_users
		askers = User.askers
		new_user_questions = Question.find(askers.collect(&:new_user_q_id)).group_by(&:created_for_asker_id)
		askers.each do |asker|
			stop = false
			new_followers = Post.twitter_request { asker.twitter.follower_ids.ids.first(50) } || []
	    new_followers.each do |tid|
	      break if stop
	      follow_response = Post.twitter_request { asker.twitter.follow(tid) }
	      stop = true if follow_response.blank?
	      sleep(1)
	      user = User.find_or_create_by_twi_user_id(tid)
	      next if new_user_questions[asker.id].blank? or asker.posts.where(:provider => 'twitter', :interaction_type => 4, :in_reply_to_user_id => user.id).count > 0
	      p "sending dm to user: #{user.id}"
	      Post.dm(asker, user, "Here's your first question! #{new_user_questions[asker.id][0].text}", {:intention => "initial question dm"})
	      Mixpanel.track_event "DM question to new follower", {
	        :distinct_id => user.id,
	        :account => asker.twi_screen_name
	      }
	      sleep(1)   
	    end
	  end

	  answered_dm_users = User.where("learner_level = 'dm answer' and created_at > ?", 1.week.ago).includes(:posts)
		app_posts = Post.where("in_reply_to_user_id in (?) and intention = 'new user question mention'", answered_dm_users.collect(&:id)).group_by(&:in_reply_to_user_id)
		popular_asker_publications = {}
		answered_dm_users.each do |user|
			if app_posts[user.id].blank?
				asker = askers.find(user.posts.first.in_reply_to_user_id)
				unless publication = popular_asker_publications[asker.id]
					if popular_post = asker.posts.includes(:conversations).where("created_at > ? and interaction_type = 1", 1.week.ago).sort_by {|p| p.conversations.size}.last
						publication_id = popular_post.publication_id
					else
						publication_id = asker.posts.where("interaction_type = 1").order("created_at DESC").limit(1).first.publication_id
					end
					publication = Publication.includes(:question).find(publication_id)
					popular_asker_publications[asker.id] = publication
				end
				puts "sending mention question to #{user.twi_screen_name}"
				Post.tweet(asker, "Next question! #{publication.question.text}", {
					:reply_to => user.twi_screen_name,
			    :long_url => "#{URL}/feeds/#{asker.id}/#{publication.id}", 
			    :interaction_type => 2, 
			    :link_type => "mention_question", 
			    :in_reply_to_user_id => user.id,
			    :publication_id => publication.id,
			    :intention => "new user question mention",
          :posted_via_app => true,
          :requires_action => false,
          :link_to_parent => false		    
				})
				Mixpanel.track_event "new user question mention", {
					:distinct_id => user.id, 
					:account => asker.twi_screen_name
				}
			end	
		end

	  ## NEED FOLLOWERS ASSOCIATION TO FIND UNENGAGED RECENT FOLLOWERS
		# users = User.where("learner_level = 'unengaged' or learner_level = 'dm answer' and created_at > ?", 1.week.ago).group_by(&:learner_level)
		# posts = Post.where("in_reply_to_user_id in (?)", users['unengaged'].collect(&:id)).order("created_at DESC").group_by(&:in_reply_to_user_id)
		# users['unengaged'].each do |user|
		# 	if posts[user.id].present?
		# 		last_post = posts[user.id].last
		# 		if last_post.intention == "initial dm question" and last_post.created_at > 3.days.ago }
		# 			# pick popular
		# 			Post.dm(asker, user, "Pop quiz: #{new_user_questions[asker.id][0].text}", {:intention => "second attempt question dm"})
		#       Mixpanel.track_event "second attempt question DM", {
		#         :distinct_id => user.id,
		#         :account => asker.twi_screen_name
		#       }
		#       sleep(1)						
		# 		end			
		# 	end
		# end
		# posts = Post.where("in_reply_to_user_id in (?) and interaction_type = 2", users['dm answer'].collect(&:id)).group_by(&:in_reply_to_user_id)
		# users['dm answer'].each do |user|
		# 	if posts[user.id].blank?
		# 		# send mention question
		# 		Post.tweet()
		# 		Mixpanel.track_event "", {

		# 		}
		# 	end	
		# end
	end

 	def self.reengage_incorrect_answerers
    askers = User.askers
    current_time = Time.now
    range_begin = 24.hours.ago
    range_end = 23.hours.ago
    
    puts "Current time: #{current_time}"
    puts "range = #{range_begin} - #{range_end}"
    
    recent_posts = Post.where("user_id is not null and ((correct = ? and created_at > ? and created_at < ? and interaction_type = 2) or ((intention = ? or intention = ?) and created_at > ?))", false, range_begin, range_end, 'reengage', 'incorrect answer follow up', range_end).includes(:user)
    user_grouped_posts = recent_posts.group_by(&:user_id)
    asker_ids = askers.collect(&:id)
    user_grouped_posts.each do |user_id, posts|
      # should ensure only one tweet per user as well here?
      next if asker_ids.include? user_id or recent_posts.where("(intention = ? or intention = ?) and in_reply_to_user_id = ?", 'reengage', 'incorrect answer follow up', user_id).present?
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
