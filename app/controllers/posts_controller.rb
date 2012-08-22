class PostsController < ApplicationController

	def update
		eng = Post.find(params[:post_id])
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
		eng.respond(correct) if eng
	end

	def response
		puts "RESPONSE"
		post = Post.find(params[:post_id].to_i)
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
		puts "#{params[:correct]} #{correct}"
		unless correct.nil? or post.nil?
			puts "We're IN correct!"
			asker = User.asker(params[:asker_id].to_i)
			user = post.user
			conversation = post.conversation
			post.respond(correct, conversation.publication_id, conversation.publication.question_id , asker.id)
			tweet = post.generate_response(params[:response_type])
			puts tweet
			if params[:response_type] == 'fast'
				Post.tweet(asker, tweet, '',"#{URL}/feeds/#{asker.id}/#{conversation.publication_id}", "reply answer_response #{correct ? 'correct' : 'incorrect'}", conversation.id, nil, post.id, user.id)
			else
				Post.tweet(asker, tweet, user.twi_screen_name,"#{URL}/feeds/#{asker.id}/#{conversation.publication_id}", "reply answer_response #{correct ? 'correct' : 'incorrect'}", conversation.id, nil, post.id, user.id)
			end
		else
			puts "SKIP IT!"
			post.update_attributes :responded_to => true
		end
		puts "We're OUT!"
		render :nothing => true, :status => 200
	end
end
