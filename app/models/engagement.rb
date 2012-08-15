class Engagement < ActiveRecord::Base
	belongs_to :user
	belongs_to :asker, :classname => 'User', :foreign_key => 'asker_id'
	belongs_to :post

	###Respose Bank ###
	CORRECT = 	["That's right!",
							"Correct!",
							"Yes!",
							"That's it!",
							"You got it!",
							"Perfect!",
							]
	COMPLEMENT = ["Way to go",
								"Keep it up",
								"Nice job",
								"Nice work",
								"Booyah",
								"Nice going",
								"Hear that? That's the sound of AWESOME happening",
								""]

	INCORRECT = 	["Hmmm, not quite.",
								"Uh oh, that's not it...",
								"Sorry, that's not what we were looking for.",
								"Nope. Time to hit the books (or videos)!",
								"Sorry. Close, but no cigar.",
								"Not quite.",
								"That's not it."
								]

	FAST = ["Fast fingers! Faster brain!",
						"Speed demon!",
						"Woah! Greased lightning!",
						"Too quick to handle!",
						"Winning isn't everything.  But it certainly is nice ;)",
						"Fastest Finger Award Winner!",
						"Hey, gunslinger! Fastest hands on the interwebs!"
							]
	###################

	def self.unanswered
		where(:engagement_type => nil)
	end

	### Twitter
	def self.twitter_answers
		where(:provider => 'twitter', :engagement_type => 'answer')
	end
	
	def self.twitter_nonanswer_mentions
		where(:provider => 'twitter', :engagement_type => 'nonanswer_mention')
	end

	def self.twitter_mentions
		where(:provider => 'twitter', :engagement_type => ['answer', 'nonanswer_mention'])
	end

	def self.twitter_shares
		where(:provider => 'twitter', :engagement_type => 'share')
	end

	### Facebook
	def self.facebook_answers
		where(:provider => 'facebook', :engagement_type => 'answer')
	end

	def self.facebook_shares
		where(:provider => 'facebook', :engagement_type => 'share')
	end

	### Tumblr
	def self.tumblr_answers
		where(:provider => 'tumblr', :engagement_type => 'answer')
	end

	def self.tumblr_shares
		where(:provider => 'tumblr', :engagement_type => 'answer')
	end

	### Internal
	def self.internal_answers
		where(:provider => 'quizme', :engagement_type => 'answer')
	end

	def self.check_for_engagement(current_acct)
		last_engagement = Engagement.where('provider_post_id is not null').last
		client = current_acct.twitter
		return if client.nil?
		mentions = client.mentions({:count => 50, :since_id => last_engagement.provider_post_id.to_i})
		retweets = client.retweets_of_me({:count => 50, :since_id => last_engagement.provider_post_id.to_i})
		mentions.each do |m|
			Engagement.save_mention_data(m, current_acct)
		end

		retweets.each do |r|
			Engagement.save_retweet_data(r, current_acct)
		end
		true
	end

	def self.save_mention_data(m, current_acct)
		u = User.find_or_create_by_twi_user_id(m.user.id)
		u.update_attributes(:twi_name => m.user.name,
												:twi_screen_name => m.user.screen_name,
												:twi_profile_img_url => m.user.status.nil? ? nil : m.user.status.user.profile_image_url)
		engagement = Engagement.find_or_create_by_provider_post_id(m.id.to_s)
		p = Post.find_by_provider_post_id(m.in_reply_to_status_id.to_s) if m.in_reply_to_status_id
		engagement.update_attributes(:date => "#{m.created_at.year}-#{m.created_at.month}-#{m.created_at.day}",
																 :engagement_type => nil,
																 :text => m.text,
															 	 :provider => 'twitter',
															 	 :twi_in_reply_to_status_id => m.in_reply_to_status_id.to_s,
															 	 :user_id => u.id,
															 	 :account_id => current_acct.id,
															 	 :post_id => p ? p.id : nil,
															 	 :created_at => m.created_at)
	end

	def self.save_retweet_data(r, current_acct)
		users = current_acct.twitter.retweeters_of(r.id)
		users.each do |user|
			u = User.find_or_create_by_twi_user_id(user.id)
			u.update_attributes(:twi_name => m.user.name,
													:twi_screen_name => m.user.screen_name,
													:twi_profile_img_url => m.user.status.nil? ? nil : m.user.status.user.profile_image_url)
			engagement = Engagement.find_or_create_by_provider_post_id(r.id.to_s)
			p = Post.find_by_provider_post_id(r.id.to_s)
			engagement.update_attributes(:date => Date.today.to_s,
																	 :engagement_type => 'share',
																	 :text => r.text,
																 	 :provider => 'twitter',
																 	 :twi_in_reply_to_status_id => nil,
																 	 :user_id => u.id,
																 	 :account_id => current_acct.id,
																 	 :post_id => p ? p.id : nil)
		end
	end


	def generate_response(response_type)
		case response_type
		when 'correct'
			tweet = "@#{self.user.twi_screen_name} #{CORRECT.sample} #{COMPLEMENT.sample}"
		when 'incorrect'
			tweet = "@#{self.user.twi_screen_name} #{INCORRECT.sample} Check the question and try it again!"
		when 'fast'
			tweet = "#{FAST.sample} @#{self.user.twi_screen_name} had the fastest right answer on that one!"
		else
			tweet = "@#{self.user.twi_screen_name} "
		end
		tweet
	end
end
