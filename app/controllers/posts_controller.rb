class PostsController < ApplicationController
	
	def update_engagement_type
		puts params.to_json
		Post.find(params[:id]).update_attribute(:engagement_type, params[:engagement_type])
		render :nothing => true
	end

	def update
		puts 'UPDATE'
		eng = Post.find(params[:post_id])
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
		eng.update_responded(correct) if eng
		render :nothing => true
	end

	def respond_to_post
		puts "RESPONSE"
		post = Post.find(params[:post_id].to_i)
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
		puts "#{params[:correct]} #{correct}"
		unless correct.nil? or post.nil?
			puts "We're IN correct!"
			asker = User.asker(params[:asker_id].to_i)
			user = post.user
			conversation = post.conversation
			post.update_responded(correct, conversation.publication_id, conversation.publication.question_id , asker.id)
			tweet = post.generate_response(params[:response_type])
			puts tweet
			if params[:response_type] == 'fast'
				puts 'fast'
				Post.tweet(asker, tweet, '','',"#{URL}/feeds/#{asker.id}/#{conversation.publication_id}", "reply answer_response #{correct ? 'correct' : 'incorrect'}", conversation.id, nil, post.id, user.id, false)
			else
				puts 'others'
				Post.tweet(asker, tweet, '',user.twi_screen_name,"#{URL}/feeds/#{asker.id}/#{conversation.publication_id}", "reply answer_response #{correct ? 'correct' : 'incorrect'}", "#{correct ? 'cor' : 'inc'}", conversation.id, nil, post.id, user.id, false)
			end
			render :nothing => true, :status => 200
		else
			puts "SKIP IT!"
			post.update_attributes :responded_to => true
			render :nothing => true, :status => 200
		end
		### Add these in where appropriate when re-written: ###
		# Stat.update_stat_cache("twitter_answers", 1, asker, user_post.created_at)
		# Stat.update_stat_cache("questions_answered", 1, asker, user_post.created_at)
		# Stat.update_stat_cache("mentions", 1, asker, user_post.created_at)
		# Stat.update_stat_cache("retweets", 1, asker, post.created_at)
		# Stat.update_stat_cache("active_users", user.id, asker, post.created_at)      		
	end
end
