class EngagementsController < ApplicationController

	def update
		eng = Engagement.find(params[:engagement_id])
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
		eng.respond(correct) if eng
	end
end
