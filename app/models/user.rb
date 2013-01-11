class User < ActiveRecord::Base
	has_many :reps
	has_many :questions
	has_many :askables, :class_name => 'Question', :foreign_key => 'created_for_asker_id'
	has_many :transitions

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

  # Lifecycle segmentation scopes
  scope :unengaged, where("lifecycle_segment is null")
  scope :edger, where(:lifecycle_segment => 1)
  scope :noob, where(:lifecycle_segment => 2)
  scope :regular, where(:lifecycle_segment => 3)
  scope :advanced, where(:lifecycle_segment => 4)
  scope :pro, where(:lifecycle_segment => 5)
  scope :superuser, where(:lifecycle_segment => 6)

  # Activity segmentation scopes
  scope :disengaged, where(:activity_segment => 1)
  scope :disengaging, where(:activity_segment => 2)
  scope :engaging, where(:activity_segment => 3)
  scope :engaged, where(:activity_segment => 4)

  # Interaction segmentation scopes
  scope :dmer, where(:interaction_segment => 1)
  scope :sharer, where(:interaction_segment => 2)
  scope :commenter, where(:interaction_segment => 3)
  scope :twitter_answerer, where(:interaction_segment => 4)
  scope :wisr_answerer, where(:interaction_segment => 5)
  scope :author, where(:interaction_segment => 6)

  # Author segmentation scopes
  scope :not_author, where("author_segment is null")
  scope :unapproved_author, where(:author_segment => 1)
  scope :message_author, where(:author_segment => 2)
  scope :wisr_author, where(:author_segment => 3)
  scope :handle_author, where(:author_segment => 4)


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
			client = Twitter::Client.new(
				:consumer_key => SERVICES['twitter']['key'],
				:consumer_secret => SERVICES['twitter']['secret'],
				:oauth_token => self.twi_oauth_token,
				:oauth_token_secret => self.twi_oauth_secret
			)
		end
		client
	end

	def tumblr
		if self.tumblr_enabled?
			client = Tumblife::Client.new(
				:consumer_key => SERVICES['tumblr']['key'],
				:consumer_secret => SERVICES['tumblr']['secret'],
				:oauth_token => self.tum_oauth_token,
				:oauth_token_secret => self.tum_oauth_secret
			)
		end
		client
	end

	def app_answer asker, post, answer, options = {}
    if options[:post_aggregate_activity] == true
      user_post = Post.create({
        :user_id => self.id,
        :provider => 'wisr',
        :text => answer.text,
        :in_reply_to_post_id => post.id, 
        :in_reply_to_user_id => asker.id,
        :posted_via_app => true, 
        :requires_action => false,
        :interaction_type => 2,
        :correct => answer.correct,
        :intention => 'respond to question'
      })      
      asker.update_aggregate_activity_cache(self, answer.correct)
    else
      user_post = Post.tweet(self, answer.text, {
        :reply_to => asker.twi_screen_name,
        :long_url => "#{URL}/feeds/#{asker.id}/#{post.publication_id}", 
        :interaction_type => 2, 
        :link_type => answer.correct ? "cor" : "inc", 
        :in_reply_to_post_id => post.id, 
        :in_reply_to_user_id => asker.id,
        :link_to_parent => false, 
        :correct => answer.correct,
        :intention => 'respond to question'
      })
    end

    self.update_user_interactions({
      :learner_level => "feed answer", 
      :last_interaction_at => user_post.created_at,
      :last_answer_at => user_post.created_at
    })

    user_post
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

	def enrolled_in_experiment? experiment_name
		experiments = Split.redis.hkeys("user_store:#{self.id}").map { |e| e.split(":")[0] }
		experiments.include? experiment_name
	end

	def transition segment_name, to
		return if to == (from = self.send("#{segment_name}_segment"))

		self.update_attribute "#{segment_name}_segment", to

		case segment_name
		when 'lifecycle'
			segment_type = 1
		when 'activity'
			segment_type = 2
		when 'interaction'
			segment_type = 3
		when 'author'
			segment_type = 4
		end

		Transition.create({
			:user_id => self.id,
			:segment_type => segment_type,
			:from => from,
			:to => to
		})	
	end
end
