class EngagementsController < ApplicationController

	def update
		eng = Engagement.find(params[:engagement_id])
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
		eng.respond(correct) if eng
	end

	def response
		eng = Engagement.find(params[:engagement_id].to_i)
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
		#eng.respond(correct) if eng
		unless correct.nil?
			puts "We're IN!"
			tweet = eng.generate_response(params[:response_type])
			puts tweet
			asker = User.asker(params[:asker_id].to_i)
			puts asker.to_json
			Post.tweet(asker, tweet, nil, nil, nil, nil, eng.post.provider_post_id)
			render :nothing => true, :status => 200
		end
	end
end
