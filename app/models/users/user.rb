class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :validatable
  devise :database_authenticatable, :registerable,
         :recoverable, :timeoutable, :trackable, 
         :omniauthable, :token_authenticatable, :rememberable # error on remember_expired? if rememberable removed, 

  def timeout_in
  	1.year
  end

  # Setup accessible (or protected) attributes for your model
  # attr_accessible :email, :password, :password_confirmation, :remember_me
  has_and_belongs_to_many :tags, -> { uniq }
  
  has_many :authorizations, :dependent => :destroy

	has_many :reps
	has_many :questions
	has_many :askables, :class_name => 'Question', :foreign_key => 'created_for_asker_id'
	has_many :transitions

	has_many :topics, -> { uniq }, through: :askertopics
	has_many :askertopics, :foreign_key => 'asker_id'
	has_many :stats, :foreign_key => 'asker_id'
	has_many :posts
	has_many :publications, :foreign_key => 'asker_id'
	has_many :engagements, :class_name => 'Post', :foreign_key => 'in_reply_to_user_id'
	has_one :publication_queue, :foreign_key => 'asker_id'
	
  has_many :badges, -> { uniq }, :through => :issuances
  has_many :issuances

  # has_many :relationships, :foreign_key => :follower_id, :dependent => :destroy
  has_many :follow_relationships, :foreign_key => :follower_id, :class_name => 'Relationship', :dependent => :destroy
  has_many :follows, -> { where("relationships.active = ?", true) }, through: :follow_relationships, source: :followed # ["relationships.active = ?", true]
  has_many :follows_with_inactive, :through => :follow_relationships, :source => :followed
  has_many :asker_follows, -> { where("relationships.active = ?", true) }, through: :follow_relationships, source: :followed, class_name: 'Asker' # ["relationships.active = ?", true], 

  # has_many :reverse_relationships, :foreign_key => :followed_id, :class_name => 'Relationship', :dependent => :destroy
  has_many :follower_relationships, :foreign_key => :followed_id, :class_name => 'Relationship', :dependent => :destroy
  has_many :followers, -> { where("relationships.active = ?", true) }, :through => :follower_relationships, :source => :follower #, :conditions => ["relationships.active = ?", true]
  has_many :followers_with_inactive, :through => :follower_relationships, :source => :follower

  has_many :exams

  belongs_to :search_term, foreign_key: :search_term_topic_id, class_name: 'Topic'

  validates_format_of :email, :with => /[a-zA-Z0-9\_.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z0-9\-.]+/, :if => Proc.new { |user| user.email.present? }

  scope :supporters, -> { where("users.role == 'supporter'") }
  scope :not_asker, -> { where("users.role != 'asker'") }
  scope :not_asker_not_us, -> { where("users.id not in (?) and users.role != 'asker'" , ADMINS) }

  scope :not_spam_with_posts, -> { joins(:posts)\
    .where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)\
    .where("role in ('user','author')") }

  scope :social_not_spam_with_posts, -> { joins(:posts)\
    .where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)\
    .where("role in ('user','author')")\
    .where('interaction_type IN (2,3)') }

  scope :teacher, -> { joins(:tags).where('tags.name = ?', 'teacher') }
  scope :student, -> { joins(:tags).where('tags.name = ?', 'student') }

  # Lifecycle segmentation scopes
  scope :unengaged, -> { where("lifecycle_segment is null") }
  scope :interested, -> { where(:lifecycle_segment => 7) }
  scope :edger, -> { where(:lifecycle_segment => 1) }
  scope :noob, -> { where(:lifecycle_segment => 2) }
  scope :regular, -> { where(:lifecycle_segment => 3) }
  scope :advanced, -> { where(:lifecycle_segment => 4) }
  scope :pro, -> { where(:lifecycle_segment => 5) }
  scope :superuser, -> { where(:lifecycle_segment => 6) }

  # Activity segmentation scopes
  scope :unfollowed, -> { where(:activity_segment => 7) }
  scope :disengaged, -> { where(:activity_segment => 1) }
  scope :disengaging, -> { where(:activity_segment => 2) }
  scope :slipping, -> { where(:activity_segment => 3) }
  scope :active, -> { where(:activity_segment => 4) }
  scope :engaging, -> { where(:activity_segment => 5) }
  scope :engaged, -> { where(:activity_segment => 6) }

  # Author segmentation scopes
  scope :not_author, -> { where("author_segment is null") }
  scope :unapproved_author, -> { where(:author_segment => 1) }
  scope :message_author, -> { where(:author_segment => 2) }
  scope :wisr_author, -> { where(:author_segment => 3) }
  scope :handle_author, -> { where(:author_segment => 4) }

  # communication preference scopes
  scope :tweeters, -> { where(:communication_preference => 1) }
  scope :emailers, -> { where(:communication_preference => 2) }
  # scope :texters, -> { where(:communication_preference => 3) }
  # scope :whatsappers, -> { where(:communication_preference => 4) }

  def self.tfind name
  	self.find_by(twi_screen_name: name)
  end

  def is_admin? 
  	ADMINS.include?(id)
  end

  def prefers_twitter?
  	communication_preference == 1
  end

  def prefers_email?
  	communication_preference == 2
  end

  def twi_profile_img_med_url
  	twi_profile_img_url.sub("_normal.", "_reasonably_small.")
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

  def self.supporters
    where(:role => 'supporter')
  end

	def self.askers
		where(:role => 'asker')
	end

	def self.asker(id)
		find_by(role: 'asker', id: id)
	end

	def is_role?(role)
		self.role.include? role.downcase
	end

	def is_teacher?
		tags.where("name = 'teacher'").size > 0
	end

	def lifecycle_above? segment_id
		return false if lifecycle_segment.nil?
		return false if SEGMENT_HIERARCHY[1].index(segment_id).blank?
		return true if segment_id.nil?
		return true if SEGMENT_HIERARCHY[1].index(lifecycle_segment) > SEGMENT_HIERARCHY[1].index(segment_id)
		false
	end

	def is_author?
		questions.size > 0
	end

	def twitter_enabled?
		authorizations.where(provider: 'twitter').where('token is not null').present?
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

	def dm_conversation_history_with_asker asker_id
		Post.dms.where("(user_id = ? and in_reply_to_user_id = ?) or (user_id = ? and in_reply_to_user_id = ?)", id, asker_id, asker_id, id).order("created_at ASC")
	end

	def is_follower_of? asker
		following = Post.twitter_request { asker.twitter.friendship?(twi_user_id, asker.twi_user_id) }
		asker.followers << self if following and !asker.followers.include? self
		return following
	end

	def app_answer asker, post, answer, options = {}
		if options[:post_to_twitter]
      user_post = self.send_public_message(answer.text, {
        :reply_to => asker.twi_screen_name,
        :long_url => "#{URL}/feeds/#{asker.id}/#{post.publication_id}", 
        :interaction_type => 2, 
        :link_type => answer.correct ? "cor" : "inc", 
        :in_reply_to_post_id => post.id, 
        :in_reply_to_user_id => asker.id,
        :link_to_parent => false, 
        :correct => answer.correct,
        :intention => 'respond to question',
        :conversation_id => options[:conversation_id],
        :in_reply_to_question_id => options[:in_reply_to_question_id]
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
	      :intention => 'respond to question',
	      :conversation_id => options[:conversation_id],
	      :in_reply_to_question_id => options[:in_reply_to_question_id]
	    })  
		end

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

	# Following two methods should be combined in the future... 
	def activity options = {} # for activity feed
		options.reverse_merge!(:since => 1.month.ago)

    answers = posts.includes(:in_reply_to_question, :in_reply_to_user)\
      .answers\
      .where("created_at > ?", options[:since])\
      .map {|p| {created_at: p.created_at, verb: 'answered', text: p.in_reply_to_question.text, profile_image_url: p.in_reply_to_user.twi_profile_img_url, href: "/questions/#{p.in_reply_to_question_id}", twi_screen_name: p.in_reply_to_user.twi_screen_name, correct: p.correct}}

    mods = self.becomes(Moderator).post_moderations.includes(:post => :in_reply_to_user)\
      .where("created_at > ?", options[:since])\
      .map {|m| {created_at: m.created_at, verb: 'moderated', text: m.post.text, profile_image_url: m.post.in_reply_to_user.twi_profile_img_url, twi_screen_name: m.post.in_reply_to_user.twi_screen_name}}  

    ugc = questions.includes(:asker)\
      .ugc.where("status != -1")\
      .where("created_at > ?", options[:since])\
      .map {|q| {created_at: q.created_at, verb: 'wrote', text: q.text, profile_image_url: q.asker.twi_profile_img_url, href: "/askers/#{q.created_for_asker_id}/questions", twi_screen_name: q.asker.twi_screen_name}}

    (answers + mods + ugc).sort_by { |e| e[:created_at] }.reverse		
	end

	def activity_summary options = {} # used for generating progress reports
		options.reverse_merge!(:since => 99.years.ago)
		activity_hash = {}
		
		answers = {}
    posts.answers.where('created_at > ?', options[:since]).group_by(&:in_reply_to_user_id).each do |asker_id, period_posts|
      answers[asker_id] = {:count => 0, :correct => 0}
      answers[asker_id][:count] = period_posts.count
      answers[asker_id][:correct] = period_posts.count { |post| post.correct }
      answers[asker_id][:lifetime_total] = posts.answers.where("in_reply_to_user_id = ?", asker_id).size
      if options[:include_progress]
       	answer_count = posts.answers.where("in_reply_to_user_id = ? and correct = ?", asker_id, true).collect(&:in_reply_to_question_id).uniq
       	total_questions = Question.where("created_for_asker_id = ?", asker_id).size
       	answer_count.delete(nil)
       	answers[asker_id][:progress] = ((answer_count.size.to_f / total_questions.to_f) * 100).ceil
			end
    end
    activity_hash[:answers] = answers

    if options[:include_ugc]
    	activity_hash[:ugc] = {}
    	activity_hash[:ugc][:answered_count] = get_my_questions_answered_this_week_count
    	activity_hash[:ugc][:written_count] = questions.where('created_at > ?', options[:since]).size
    end

    if options[:include_moderated]
    	activity_hash[:moderated] = self.becomes(Moderator).post_moderations.where("created_at > ?", options[:since]).size
    end

		activity_hash
  end

  def get_my_questions_answered_this_week_count
  	Post.answers.where("created_at > ? and in_reply_to_question_id in (?)", 1.week.ago, questions.collect(&:id)).count
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
			return ab_user.get_key(experiment.key) if experiment.key
		else
			return false
		end
	end

	def after_new_user_filter
    Mixpanel.track_event "new user joined", {
      :distinct_id => id,
      :type => "twitter"
    }
    classify
		register_referrals
		Post.trigger_split_test(id, "targeted mention script (joins)")
	end

	def classify matched_tags = []
		USER_TAG_SEARCH_TERMS.each do |tag_name, terms|
			terms.each do |term| 
				matched_tags << tag_name if twi_screen_name and twi_screen_name.include? term
				matched_tags << tag_name if description and description.include? term 
			end
		end
		Tag.where('name in (?)', matched_tags).each { |matched_tag| tags << matched_tag } if matched_tags.present?
	end

	def register_referrals 
		followed_twi_user_ids = Post.twitter_request { User.find_by_twi_screen_name('Wisr').twitter.friend_ids(twi_user_id).ids } || [0]
		referrers = User.not_asker.where("twi_user_id in (?)", followed_twi_user_ids)
		if referrers.present?
			referrers.each { |referrer| 
				Post.trigger_split_test(referrer.id, "Refer a friend script (follower joins)") 
				Post.trigger_split_test(referrer.id, 'UGC published notification type (follower joins)')
			}
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
		when :moderator
			segment_type = 5
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

		Post.trigger_split_test(id, "weekly progress report") if transition.segment_type == 1 and transition.is_positive?
		Post.trigger_split_test(id, "DM autoresponse interval v2 (activity segment +)") if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(1)
		Post.trigger_split_test(id, 'other feeds panel shows related askers (=> regular)') if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(2)
		Post.trigger_split_test(id, "logged in home page (=> advanced)") if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(3)
		Post.trigger_split_test(id, 'send link to activity feed (=> pro)') if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(4)
		Post.trigger_split_test(id, 'link to activity feed script (=> pro)') if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(4)
		Post.trigger_split_test(id, 'grading on mod manage displays actions via growl (mod => regular)') if transition.segment_type == 5 and transition.is_positive? and transition.is_above?(2)
		Post.trigger_split_test(id, 'include solicitations as reengagements (=> advanced)') if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(3)
		Post.trigger_split_test(id, 'followup ugc request type (=> superuser)') if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(5)
		Post.trigger_split_test(id, 'Weekly progress report email (=> superuser)') if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(5)

		if transition.segment_type == 1 and transition.is_positive? and transition.is_above?(3) and search_term
			search_term.askers.each { |asker| Post.trigger_split_test(id, "#{asker.twi_screen_name} search terms (=> advanced)") }
		end
	end

  def lifecycle_transition_comment to_segment
    return nil if has_received_transition_to_comment?(1, to_segment) # make sure user hasn't already received a comment for this transition or one above
    
    #find asker
    asker = Asker.find_by(id: posts.order("created_at DESC").first.in_reply_to_user_id)
    return nil if asker.nil?

    #default no comment
    intention = nil
    no_comment = "No comment"

    to_seg_test_name = {
      1 => "to edger lifecycle transition comment (=> noob)",
      2 => "to noob lifecycle transition comment (=> regular)",
      3 => "email solicitation script (=> advanced)",
      4 => "to advanced lifecycle transition comment v3 (=> pro)",
      5 => "to pro lifecycle transition comment (=> superuser)"
    }

    case to_segment
    when 1 #to edger
      comment = no_comment
    when 2 #to noob
      comment = no_comment
    when 3 #to regular
      comment = Post.create_split_test(id, to_seg_test_name[to_segment], 
        no_comment, 
        "I'm going to start sending a weekly progress report, what's your email address?"
      )
    	intention = 'request email'
    when 4 #to advanced - suggestions?
      comment = Post.create_split_test(id, to_seg_test_name[to_segment], 
        no_comment, 
        "You're off to a strong start. How can I make this better?"
      )
      Post.trigger_split_test(id, to_seg_test_name[to_segment - 1])
    when 5 #to pro - great commitment
      comment = "Fantastic dedication to this material."
      Post.trigger_split_test(id, to_seg_test_name[to_segment - 1])
    when 6 #to superuser
	    Post.trigger_split_test(id, to_seg_test_name[to_segment - 1])
    end

    unless comment == no_comment or comment.nil?
      asker.send_private_message(self, comment, {:intention => (intention || "lifecycle+")})
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
		Post.trigger_split_test(id, "Personalized reengagement question (age > 15 days)") if age_greater_than 15.days
	end

	# Lifecycle checks - include UGC reqs?
	def update_lifecycle_segment
		@posts = posts
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
		@posts.not_spam.size > 0
	end

	def is_edger? # has answered a new user private message
		@posts.not_spam.answers.dms.size > 0
	end

	def is_noob? # has answered socially (wisr or twi mention)
		@posts.social.answers.size > 0
	end

	def is_regular?
		enough_posts = true if @posts.answers.size > 3
		enough_frequency = true if number_of_weeks_with_answers > 1
		enough_posts and enough_frequency
	end

	def is_advanced?
		enough_posts = true if @posts.answers.size > 9
		enough_frequency = true if number_of_weeks_with_answers > 1 and number_of_days_with_answers > 2
		enough_posts and enough_frequency
	end

	def is_pro?
		enough_posts = true if @posts.answers.size > 19
		enough_frequency = true if number_of_weeks_with_answers > 2 and number_of_days_with_answers > 4
		enough_posts and enough_frequency		
	end

	def is_superuser?
		enough_posts = true if @posts.answers.size > 29
		enough_frequency = true if number_of_weeks_with_answers > 4 and number_of_days_with_answers > 9
		enough_posts and enough_frequency
	end

	# Activity checks
	def update_activity_segment	
		@posts = posts
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
		@posts.blank? or posts.answers.where("created_at > ?", 4.weeks.ago).size < 1
	end

	def is_disengaging?
		@posts.answers.where("created_at > ?", 2.weeks.ago).size < 1
	end

	def is_slipping?
		@posts.answers.where("created_at > ?", 1.weeks.ago).size < 1
	end

	def is_engaging?
		number_of_days_with_answers(:posts => @posts.where("created_at > ?", 1.week.ago)) > 1
	end

	def is_engaged?
		number_of_days_with_answers(:posts => @posts.where("created_at > ?", 1.week.ago)) > 2
	end


	def age_greater_than age = 15.days
		return false if posts.blank?
		(posts.order("created_at DESC").first.created_at.to_i - created_at.to_i) > age.to_i
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

  def select_reengagement_asker
    answer_count_by_asker = posts\
      .answers\
      .where("in_reply_to_user_id in (?)", follows.collect(&:id))\
      .where("in_reply_to_user_id in (?)", Asker.published_ids)\
      .select(["user_id", "count(in_reply_to_user_id) as count"])\
      .group("in_reply_to_user_id")\
      .count  
    (answer_count_by_asker.empty? ? asker_follows.sample : Asker.find(answer_count_by_asker.max_by{|k,v| v}.first))  
  end

  def pick_reengagement_type last_active_at
  	question_prevalence_by_sent_count = { 0 => 1.0, 1 => 0.8, 2 => 0.7, 3 => 0.6, 4 => 0.5, 5 => 0.33 }
  	# question_prevalence_by_sent_count = { 0 => 0.33, 1 => 0.33, 2 => 0.33, 3 => 0.33, 4 => 0.33, 5 => 0.33 }
  	valid_non_question_types = [:moderation, :author]
  	reengagements_sent = Post.reengage_inactive.where("in_reply_to_user_id = ? and created_at > ?", id, last_active_at).count
  	valid_non_question_types.delete(:moderation) unless Post.requires_moderations(self).present?
  	if rand < (question_prevalence_by_sent_count[reengagements_sent] || 1 )
  		return :question
  	else
  		return valid_non_question_types.sample
  	end
  end

  def questions_answered_ids_by_asker asker_id, question_ids = []
  	posts.where("in_reply_to_user_id = ?", asker_id).includes(:conversation => {:publication => :question}).answers.each do |answer_post|
  		question = answer_post.in_reply_to_question || answer_post.conversation.try(:publication).try(:question)
  		question_ids << question.id if question
  	end
  	questions.each { |q| question_ids << q.id } # don't ask users questions that they wrote
  	question_ids.uniq
  end

  def self.get_ids_to_last_active_at period
    user_ids_to_last_active_at = Hash[*Post.not_spam.answers.not_asker.where('posts.interaction_type IN (2,3,5)')\
      .select(["user_id", "max(created_at) as last_active_at"])\
      .where("created_at > ?", period.days.ago)\
      .group("user_id").map{|p| [p.user_id, p.last_active_at.time]}.flatten]

    moderation_user_ids_to_last_active_at = Hash[*Moderation.select(["user_id", "max(created_at) as last_active_at"])\
      .where("created_at > ?", period.days.ago)\
      .group("user_id").map{|p| [p.user_id, p.last_active_at.time]}.flatten]

    question_user_ids_to_last_active_at = Hash[*Question.not_us\
      .select(["user_id", "max(created_at) as last_active_at"])\
      .where("created_at > ?", period.days.ago)\
      .group("user_id").map{|p| [p.user_id, p.last_active_at.time]}.flatten]

    user_ids_to_last_active_at.reverse_merge!(moderation_user_ids_to_last_active_at)\
      .reverse_merge!(question_user_ids_to_last_active_at)
    user_ids_to_last_active_at.merge!(moderation_user_ids_to_last_active_at) { |key, v1, v2| v1 > v2 ? v1 : v2 }\
      .merge!(question_user_ids_to_last_active_at) { |key, v1, v2| v1 > v2 ? v1 : v2 }

    return user_ids_to_last_active_at
  end  
end
