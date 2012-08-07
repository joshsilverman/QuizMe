class Engagement < ActiveRecord::Base
	belongs_to :mention
	belongs_to :user
	belongs_to :account

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
end
