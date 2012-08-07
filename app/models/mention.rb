class Mention < ActiveRecord::Base
	belongs_to :user
	belongs_to :post
	has_one :engagement

	def self.unanswered
		where(:responded => false)
	end

	def respond_correct
		correct = ["That's right!",
								"Correct!",
								"Yes!",
								"That's it!",
								"You got it!",
								"Perfect!",
							]
		complement = ["Way to go",
									"Keep it up",
									"Nice job",
									"Nice work",
									"Booyah",
									"Nice going",
									"Hear that? That's the sound of AWESOME happening",
									""]
		account = Account.find(self.post.account_id)
		tweet = "@#{self.user.twi_screen_name} #{correct.sample} #{complement.sample}"
		q = self.post.question
		url = "http://www.studyegg.com/review/#{q.qb_lesson_id}/#{q.qb_q_id}"
		if account.link_to_quizme
			url = "http://studyegg-quizme.herokuapp.com/feeds/#{account.id}"
		end
		Post.tweet(account, tweet, url, 'cor', q.id)
	end

	def respond_incorrect
		incorrect = ["Hmmm, not quite.",
								"Uh oh, that's not it...",
								"Sorry, that's not what we were looking for.",
								"Nope. Time to hit the books (or videos)!",
								"Sorry. Close, but no cigar.",
								"Not quite.",
								"That's not it."
							]
		account = Account.find(self.post.account_id)
		tweet = "@#{self.user.twi_screen_name} #{incorrect.sample} Check the question and try it again!"
		q = self.post.question
		url = "http://www.studyegg.com/review/#{q.qb_lesson_id}/#{q.qb_q_id}"
    if account.link_to_quizme
      url = "http://studyegg-quizme.herokuapp.com/feeds/#{account.id}"
    end
		Post.tweet(account, tweet, url, 'inc', nil)
	end

	def respond_first
		fast = ["Fast fingers! Faster brain!",
						"Speed demon!",
						"Woah! Greased lightning!",
						"Too quick to handle!",
						"Winning isn't everything.  But it certainly is nice ;)",
						"Fastest Finger Award Winner!",
						"Hey, gunslinger! Fastest hands on the interwebs!"
							]
		account = Account.find(self.post.account_id)
		tweet = "#{fast.sample} @#{self.user.twi_screen_name} had the fastest right answer on that one!"
		q = self.post.question
		url = "http://www.studyegg.com/review/#{q.qb_lesson_id}/#{q.qb_q_id}"
    if account.link_to_quizme
      url = "http://studyegg-quizme.herokuapp.com/feeds/#{account.id}"
    end
		Post.tweet(account, tweet, url, 'fast', nil)
	end


	def self.check_mentions(current_acct)
		last_mention = Mention.where('twi_tweet_id is not null').last
		client = current_acct.twitter
		return if client.nil?
		mentions = client.mentions({:count => 50, :since_id => last_mention.twi_tweet_id})
		retweets = client.retweets_of_me({:count => 50, :since_id => last_mention.twi_tweet_id})
		mentions.each do |m|
			Mention.save_mention_data(m)
		end

		retweets.each do |r|
			Mention.save_retweet_data(client, r)
		end
		true
	end

	def self.save_mention_data(m)
		u = User.find_or_create_by_twi_user_id(m.user.id)
		u.update_attributes(:twi_name => m.user.name,
												:twi_screen_name => m.user.screen_name,
												:twi_profile_img_url => m.user.status.user.profile_image_url)
		mention = Mention.find_or_create_by_twi_tweet_id(m.id.to_s)
		unless mention.text == m.text and 
			mention.twi_in_reply_to_status_id == m.in_reply_to_status_id.to_s and
			mention.user_id == u.id and
			mention.sent_date == m.created_at
				mention.update_attributes(:text => m.text,
					:twi_in_reply_to_status_id => m.in_reply_to_status_id.to_s,
					:user_id => u.id,
					:sent_date => m.created_at)
		end
		mention.link_mention_to_post
		if mention.post
			eng = Engagement.find_or_create_by_user_id_and_mention_id(u.id, mention.id)
			eng.update_attributes(:date => Date.today.to_s,
														:account_id => mention.post.account_id,
														:provider => mention.post.provider,
														:engagement_type => 'answer')
		end
	end

	def self.save_retweet_data(client, r)
		post = Post.find_by_provider_post_id(r.id.to_s)
		if post
			users = client.retweeters_of(r.id)
			users.each do |u|
				user = User.find_or_create_by_twi_user_id(u.id)
				user.update_attributes(:twi_name => u.name,
														:twi_screen_name => u.screen_name,
														:twi_profile_img_url => u.status.nil? ? nil : u.status.user.profile_image_url)
				mention = Mention.create()
				unless mention.text == r.text and 
					mention.twi_in_reply_to_status_id == r.in_reply_to_status_id.to_s and
					mention.user_id == user.id and
					mention.sent_date == m.created_at
						mention.update_attributes(:text => r.text,
							:twi_in_reply_to_status_id => r.in_reply_to_status_id.to_s,
							:user_id => user.id,
							:sent_date => Time.now)
				end
				eng = Engagement.find_or_create_by_user_id_and_mention_id(user.id, mention.id)
				eng.update_attributes(:date => Date.today.to_s,
															:account_id => post.account_id,
															:provider => post.provider,
															:engagement_type => 'share')
			end
		end
	end

	def link_mention_to_post
		if self.twi_in_reply_to_status_id
			p = Post.find_by_provider_post_id(self.twi_in_reply_to_status_id.to_s)
			self.update_attributes(:post_id => p.id) if p
		elsif self.text =~ /bit.ly/
			msg = self.text
			link_pos = msg =~ /bit.ly/
			sp = msg.index(/ /,link_pos)
			sp = -1 if sp.nil?
			bitly_link = msg.slice(link_pos..sp)
			p = nil
			p = Post.find_by_url("http://#{bitly_link}") unless bitly_link.nil?
			self.update_attributes(:post_id => p.id) if p
		end
	end
end
