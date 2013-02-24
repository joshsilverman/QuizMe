class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :validatable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :omniauthable

  # Setup accessible (or protected) attributes for your model
  # attr_accessible :email, :password, :password_confirmation, :remember_me
  
  has_many :authorizations, :dependent => :destroy

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

  scope :supporters, where("users.role == 'supporter'")
  scope :not_asker, where("users.role != 'asker'")
  scope :not_asker_not_us, where("users.id not in (?) and users.role != 'asker'" , ADMINS)

  scope :not_spam_with_posts, joins(:posts)\
    .where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)\
    .where("role in ('user','author')")\

  scope :social_not_spam_with_posts, joins(:posts)\
    .where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)\
    .where("role in ('user','author')")\
    .where('interaction_type IN (2,3)')\

  # Lifecycle segmentation scopes
  scope :unengaged, where("lifecycle_segment is null")
  scope :interested, where(:lifecycle_segment => 7)
  scope :edger, where(:lifecycle_segment => 1)
  scope :noob, where(:lifecycle_segment => 2)
  scope :regular, where(:lifecycle_segment => 3)
  scope :advanced, where(:lifecycle_segment => 4)
  scope :pro, where(:lifecycle_segment => 5)
  scope :superuser, where(:lifecycle_segment => 6)

  # Activity segmentation scopes
  scope :unfollowed, where(:activity_segment => 7)
  scope :disengaged, where(:activity_segment => 1)
  scope :disengaging, where(:activity_segment => 2)
  scope :slipping, where(:activity_segment => 3)
  scope :active, where(:activity_segment => 4)
  scope :engaging, where(:activity_segment => 5)
  scope :engaged, where(:activity_segment => 6)

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

  def self.supporters
    where(:role => 'supporter')
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
		if auth = authorizations.where(:provider => "twitter").first
			return Twitter::Client.new(
				:consumer_key => SERVICES['twitter']['key'],
				:consumer_secret => SERVICES['twitter']['secret'],
				:oauth_token => auth.token,
				:oauth_token_secret => auth.secret
			)		
		end
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

	def is_follower_of? asker
		following = Post.twitter_request { asker.twitter.friendship?(twi_user_id, asker.twi_user_id) }
		asker.followers << self if following and !asker.followers.include? self
		return following
	end

	def app_answer asker, post, answer, options = {}
		if options[:post_to_twitter]
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
    else
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
		end    

    segment

    user_post
	end

	def nudge_types # sloppy workaround - cant get has_many through to use a custom foreign key...
		NudgeType.where("id in (?)", Post.where("in_reply_to_user_id = ? and nudge_type_id is not null", id).collect(&:nudge_type_id))
	end

	def nudges_received nudge_type_id = nil
		nudges = Post.where("in_reply_to_user_id = ? and nudge_type_id is not null", id)
		nudges = nudges.where("nudge_type_id = ?", nudge_type_id) if nudge_type_id
		nudges
	end

	def update_user_interactions(params = {})
		params.delete :learner_level unless params[:learner_level] and (learner_level.blank? or LEARNER_LEVELS.index(params[:learner_level]) > LEARNER_LEVELS.index(learner_level))
		params.delete :last_interaction_at unless params[:last_interaction_at] and (last_interaction_at.blank? or params[:last_interaction_at] > last_interaction_at)
		params.delete :last_answer_at unless params[:last_answer_at] and (last_answer_at.blank? or params[:last_answer_at] > last_answer_at)
		self.update_attributes params	
	end

	def self.get_activity_summary recipient, activity_hash = {}
    recipient.posts.group_by(&:in_reply_to_user_id).each do |asker_id, posts|
      activity_hash[asker_id] = {:count => 0, :correct => 0}
      activity_hash[asker_id][:count] = posts.count
      activity_hash[asker_id][:correct] = posts.count { |post| post.correct }
      activity_hash[asker_id][:lifetime_total] = Post.answers.where("user_id = ? and in_reply_to_user_id = ?", recipient.id, asker_id).size
    end

    activity_hash.sort_by { |k, v| v[:count] }.reverse
  end

  def get_my_questions_answered_this_week_count
  	Publication.includes(:conversations).where("publications.question_id in (?) and conversations.created_at > ?", Question.where("user_id = ?", id).collect(&:id), 1.week.ago).collect {|pub| pub.conversations.size}.sum
  end

	def enrolled_in_experiment? experiment_name
		experiments = Split.redis.hkeys("user_store:#{self.id}").map { |e| e.split(":")[0] }
		experiments.include? experiment_name
	end

	def get_experiment_option experiment_name
		experiments = Split.redis.hkeys("user_store:#{self.id}").map { |e| e.split(":")[0] }
		if experiments.include? experiment_name
			experiment = Split::Experiment.find(experiment_name)
			ab_user = Split::RedisStore.new(Split.redis) 
			ab_user.set_id(id)
			return ab_user.get_key(experiment.key)
		else
			return false
		end
	end

	def after_new_user_filter
    Mixpanel.track_event "new user joined", {
      :distinct_id => id,
      :type => "twitter"
    }  		
		register_referrals
	end

	def register_referrals 
		followed_twi_user_ids = Post.twitter_request { User.find_by_twi_screen_name('Wisr').twitter.friend_ids(twi_user_id).ids } || [0]
		referrers = User.not_asker.where("twi_user_id in (?)", followed_twi_user_ids)
		if referrers.present?
			referrers.each { |referrer| Post.trigger_split_test(referrer.id, "Post to twitter on app answer (follower joins)") }
      Mixpanel.track_event "referral joined", {
        distinct_id: id,
        type: "twitter"
      }     
		end
	end


	# Segmentation methods
	def transition segment_name, to_segment
		return if to_segment == (from_segment = self.send("#{segment_name}_segment"))

		self.update_attribute "#{segment_name}_segment", to_segment

		case segment_name
		when :lifecycle
			segment_type = 1
		when :activity
			segment_type = 2
		when :interaction
			segment_type = 3
		when :author
			segment_type = 4
		end

    comment = nil
    if segment_type == 1
      comment = lifecycle_transition_comment(to_segment)
    end

    transition = Transition.create({
      :user_id => id,
      :segment_type => segment_type,
      :from_segment => from_segment,
      :to_segment => to_segment,
      :comment => comment
    })  

    after_new_user_filter if transition.segment_type == 1 and transition.from_segment.blank? and transition.to_segment.present?

		Post.trigger_split_test(id, "after answer cta (activity segment +)") if transition.segment_type == 2 and transition.is_positive?
		Post.trigger_split_test(id, "weekly progress report") if transition.segment_type == 1 and transition.is_positive?
		Post.trigger_split_test(id, "reengagement tight intervals") if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(2)
		Post.trigger_split_test(id, "auto respond") if ((transition.segment_type == 1 and transition.is_positive? and transition.is_above?(2)) or (transition.segment_type == 2 and transition.is_positive? and transition.is_above?(4)))
		Post.trigger_split_test(id, "DM autoresponse interval (activity segment +)") if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(1)
	end

  def lifecycle_transition_comment to_segment
    return nil if has_received_transition_to_comment?(1, to_segment) # make sure user hasn't already received a comment for this transition or one above
    
    #find asker
    asker = Asker.find_by_id posts.order("created_at DESC").first.in_reply_to_user_id
    return nil if asker.nil?

    #default no comment
    no_comment = "No comment"

    to_seg_test_name = {
      1 => "lifecycle smartransition to edger comment (=> noob)",
      2 => "lifecycle smartransition to noob comment (=> regular)",
      3 => "lifecycle smartransition to regular comment (=> advanced)",
      4 => "lifecycle smartransition to advanced comment (=> pro)",
      5 => "lifecycle smartransition to pro comment (=> superuser)"
    }

    case to_segment
    when 1 #to edger
      # Next step, what to expect
      comment = Post.create_split_test(id, to_seg_test_name[to_segment], 
        no_comment, 
        "Let's get started! I'll send you another question soon.",
        "Check out my tweets, I post new questions frequently!",
        "Hold tight, I'll send you another shortly..."
      )
    when 2 #to noob
      # I'll tweet you more questions // follow up
      comment = Post.create_split_test(id, to_seg_test_name[to_segment], 
        no_comment, 
        "Thanks for tweeting me your answer. I'll tweet you interesting questions as I see them.",
        "Can I tweet you interesting questions as I come accross them?",
        "Keep tweeting me your answers. I'll keep track and follow up on mistakes."
      )
      Post.trigger_split_test(id, to_seg_test_name[to_segment - 1])
    when 3 #to regular
      # start, how can i improve
      comment = Post.create_split_test(id, to_seg_test_name[to_segment], 
        "No comment", 
        "You're off to a strong start. How can I make this better?",
        "How can I make these quizzes better?",
        "You're really improving. How can I improve what I do?"
      )
      Post.trigger_split_test(id, to_seg_test_name[to_segment - 1])
    when 4 #to advanced 
      # good commitment
      comment = Post.create_split_test(id, to_seg_test_name[to_segment], 
        "No comment", 
        "If you keep up the strong commitment, you'll really (re)master this.",
        "It's great to see your commitment so far.",
        "Very strong start with this material."
      )
      Post.trigger_split_test(id, to_seg_test_name[to_segment - 1])
    when 5 #to pro
      # great commitment
      comment = Post.create_split_test(id, to_seg_test_name[to_segment], 
        "No comment", 
        "Fantastic dedication to this material.",
        "Great to see your dedication.",
        "You are well on your way to (re)mastery with this."
      )
      Post.trigger_split_test(id, to_seg_test_name[to_segment - 1])
    when 6 #to superuser
      # contribution and thank you
      comment = [ 
        "No comment", 
        "You've added so much to this community - thank you.",
        "So glad to be learning with you. Your contribution is so helpful.",
        "Your contribution to this community continues to be really helpful. Big thanks."
      ].sample
      Post.trigger_split_test(id, to_seg_test_name[to_segment - 1])
    end

    unless comment == no_comment or comment.nil?
      Post.dm(asker, self, comment, {:intention => "lifecycle+"})
      return comment
    end

    ""
  end

	def self.update_segments
		User.find_in_batches(:conditions => ["twi_screen_name is not null and role != 'asker' and id not in (?)", ADMINS]) do |group| 
			group.each { |user| user.segment }
		end
	end

	def has_received_transition_to_comment? segment_type, to_segment
		transitions.where("segment_type = ? and to_segment >= ? and comment is not null and comment != ''", segment_type, to_segment).size > 0
	end

	def segment
		update_lifecycle_segment
		update_activity_segment
		# update_interaction_segment
		# update_author_segment
	end

	# Lifecycle checks - include UGC reqs?
	def update_lifecycle_segment
		if is_superuser?
			level = 6
		elsif is_pro?
			level = 5			
		elsif is_advanced?
			level = 4
		elsif is_regular?
			level = 3
		elsif is_noob?
			level = 2		
		elsif is_edger?
			level = 1	
		elsif is_interested?
			level = 7
		else
			level = nil
		end

		transition :lifecycle, level if level
	end
	
	def is_interested? # has shared or commented
		posts.not_spam.size > 0
	end

	def is_edger? # has answered a new user private message
		posts.not_spam.answers.dms.size > 0
	end

	def is_noob? # has answered socially (wisr or twi mention)
		posts.social.answers.size > 0
	end

	def is_regular?
		enough_posts = true if posts.answers.size > 3
		enough_frequency = true if number_of_weeks_with_answers > 1
		enough_posts and enough_frequency
	end

	def is_advanced?
		enough_posts = true if posts.answers.size > 9
		enough_frequency = true if number_of_weeks_with_answers > 1 and number_of_days_with_answers > 2
		enough_posts and enough_frequency
	end

	def is_pro?
		enough_posts = true if posts.answers.size > 19
		enough_frequency = true if number_of_weeks_with_answers > 2 and number_of_days_with_answers > 4
		enough_posts and enough_frequency		
	end

	def is_superuser?
		enough_posts = true if posts.answers.size > 29
		enough_frequency = true if number_of_weeks_with_answers > 4 and number_of_days_with_answers > 9
		enough_posts and enough_frequency
	end

	# Activity checks
	def update_activity_segment	
		if is_unfollowed?
			level = 7
		elsif is_disengaged?
			level = 1
		elsif is_disengaging?
			level = 2
		elsif is_slipping?
			level = 3
		elsif is_engaged?
			level = 6
		elsif is_engaging?
			level = 5
		else
			level = 4
		end

		transition :activity, level
	end

	def is_unfollowed?
		follows.blank?
	end

	def is_disengaged?
		posts.blank? or posts.answers.where("created_at > ?", 4.weeks.ago).size < 1
	end

	def is_disengaging?
		posts.answers.where("created_at > ?", 2.weeks.ago).size < 1
	end

	def is_slipping?
		posts.answers.where("created_at > ?", 1.weeks.ago).size < 1
	end

	def is_engaging?
		number_of_days_with_answers(:posts => posts.where("created_at > ?", 1.week.ago)) > 1
	end

	def is_engaged?
		number_of_days_with_answers(:posts => posts.where("created_at > ?", 1.week.ago)) > 2
	end

	# Interaction checks
	def update_interaction_segment
		if is_PMer?
			level = 1
		elsif is_sharer?
			level = 2
		elsif is_commenter?
			level = 3
		elsif is_twitter_answerer?
			level = 4
		elsif is_wisr_answerer?
			level = 5
		end
		transition :interaction, level
	end

	def is_PMer?
		user_posts = interaction_type_grouped_posts
		user_posts[4] == interaction_type_grouped_posts.values.max
	end

	def is_sharer?
		user_posts = interaction_type_grouped_posts
		user_posts[3] == interaction_type_grouped_posts.values.max
	end

	def is_commenter?

	end

	def is_twitter_answerer?

	end

	def is_wisr_answerer?

	end

	# Author checks
	def update_author_segment
		if is_not_author?
			level = nil
		elsif is_unapproved_author?
			level = 1
		elsif is_DM_mention_author?
			level = 2
		elsif is_form_author?
			level = 3
		elsif is_handle_author?
			level = 4
		end
		transition :author, level
	end

	def is_not_author?

	end

	def is_unapproved_author?

	end

	def is_DM_mention_author?

	end

	def is_form_author?

	end

	def is_handle_author?

	end


  def number_of_weeks_with_answers options = {}
  	user_posts = options[:posts].present? ? options[:posts] : posts
    user_posts.answers.group_by {|p| p.created_at.strftime('%W-%y')}.size
  end

  def number_of_days_with_answers options = {}
  	user_posts = options[:posts].present? ? options[:posts] : posts
    user_posts.answers.group_by {|p| p.created_at.strftime('%D-%y')}.size    
  end

  def interaction_type_grouped_posts
  	posts.group('interaction_type').count
  end

  def age
    ((Time.now - posts.order('created_at ASC').first.created_at)/60/60/24).round
  end

end