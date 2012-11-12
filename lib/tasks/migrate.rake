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

		eng_correct = true if engagement_type.include? "correct" and !engagement_type.include? "answer_response"
		eng_correct = false if engagement_type.include? "incorrect" and !engagement_type.include? "answer_response"
			
		correct = post.reps.first.try(:correct)
		correct = eng_correct if correct.nil?
		correct = nil if engagement_type.include? "status"

		post.correct = correct
		post.interaction_type = type
		post.save

		# puts post.to_json
		# puts "\n\n"
	end
end

task :update_users_with_last_answer_and_interaction => :environment do
	# User.includes(:posts).all.each_with_index do |user, i|
	User.includes(:posts).where("posts.user_id is not null").each_with_index do |user, i|
		puts "#{i}. #{user.twi_screen_name}"
		posts = user.posts.not_spam.order("created_at DESC")
		last_answer = nil
		last_interaction = nil
		next unless posts.present?
		answers = posts.where("correct is not null")
		last_answer = answers.first.created_at if answers.present?
		last_interaction = posts.first.created_at
		user.update_attributes({
			:last_answer_at => last_answer,
			:last_interaction_at => last_interaction
		}) 
	end  
end

task :add_learner_level_to_users => :environment do
  User.includes(:posts).where("posts.user_id is not null").each_with_index do |user, i|
  	posts = user.posts.not_spam
  	# check for requires action?
  	if posts.where("correct is not null and posted_via_app = ? and interaction_type = 2", true).present?
  		level = "feed answer"
  	elsif posts.where("correct is not null and posted_via_app != ? and interaction_type = 2", true).present?
  		level = "twitter answer"
  	elsif posts.where("correct is not null and interaction_type = 4").present?
  		level = "dm answer"
  	elsif posts.where("correct is null and interaction_type = 2").present?
  		level = "mention"
  	elsif posts.where("interaction_type = 3").present?
  		level = "share"
  	# lots of correct = null dm answers here...
  	elsif posts.where("interaction_type = 4").present?
  		level = "dm"
  	else
  		level = "unengaged"
  	end
  	puts "#{i}. #{user.twi_screen_name} - #{level}"
  	user.update_attribute(:learner_level, level)
  end
end