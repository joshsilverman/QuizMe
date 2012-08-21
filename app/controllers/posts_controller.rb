class PostsController < ApplicationController

	def update
		eng = Post.find(params[:post_id])
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
		eng.respond(correct) if eng
	end

	def response
		post = Post.find(params[:post_id].to_i)
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
		unless correct.nil? or post.nil?
			puts "We're IN!"
			post. respond(correct)
			tweet = post.generate_response(params[:response_type])
			puts tweet
			asker = User.asker(params[:asker_id].to_i)
			parent_post = Post.find(post.in_reply_to_post_id)
			Post.tweet(asker, tweet, "reply answer_response #{correct ? 'correct' : 'incorrect'}", "http://studyegg-quizme-staging.herokuapp,com/feeds/#{asker.id}/#{parent_post.id if parent_post}", parent_post.conversation_id, nil, parent_post.id, parent_post.user_id)
			render :nothing => true, :status => 200
		end
	end
end
