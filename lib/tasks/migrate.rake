task :update_mentions_with_sent_date => :environment do
	mentions = Mention.all
	mentions.each do |m|
		if m.sent_date.nil?
			next if m.post.nil? or m.post.empty?
			puts m.id
			a = Account.find(m.post.account_id)
			t = a.twitter.status(m.twi_tweet_id.to_i)
			sent_date = t.created_at
			m.update_attributes(:sent_date => sent_date)
		end
	end
end

task :update_post_attributes => :environment do
	Post.includes(:reps).each do |post|
		# puts post.engagement_type.to_json
		engagement_type = post.engagement_type || ""
		# puts post.to_json
		if engagement_type.include? "pm"
			type = 4
		elsif engagement_type.include? "status" or engagement_type.include? "external"
			type = 1
		elsif engagement_type.include? "share"
			type = 3			
		# elsif engagement_type.include? "reply" and engagement_type.include? "answer"
		# 	type = 2
		# elsif engagement_type.include? "mention"
		# 	type = 2
		else
			type = 2			
		end

		if engagement_type.include? "correct" and !engagement_type.include? "answer_response"
			eng_correct = true
		elsif engagement_type.include? "incorrect" and !engagement_type.include? "answer_response"
			eng_correct = false
		end
		correct = post.reps.first.try(:correct)
		correct = eng_correct if correct.nil?
		correct = nil if engagement_type.include? "status"

		post.correct = correct
		post.interaction_type = type
		post.save

		puts post.to_json
		puts "\n\n"
	end
end