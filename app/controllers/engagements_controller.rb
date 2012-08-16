class EngagementsController < ApplicationController

	def update
		eng = Engagement.find(params[:engagement_id])
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil

		puts eng.inspect
		if eng
	  	eng.update_attributes(:responded => true)
	  	Rep.create(:user_id => eng.user_id, :post_id => eng.post_id, :correct => correct) unless correct.nil?

	  	case correct
	  	when true
		  	stat = Stat.find_or_create_by_date_and_asker_id(Date.today.to_s, m.post.asker_id)
		  	stat.increment(:questions_answered_today)
		  	#m.post.mentions.order('sent_date DESC').limit(10).first
		  	if first
		  		m.respond_first
		  	else
		  		m.respond_correct
		  	end
	  	when false
	  		stat = Stat.find_or_create_by_date_and_account_id(Date.today.to_s, m.post.account_id)
		  	stat.increment(:questions_answered_today)
		  	m.respond_incorrect
	  	when nil
	  		puts 'skipped'
	  	else
	  		puts 'an error has occurred:: MentionsController :: LINE 24'
	  	end
	  	#render :nothing => true, :status => 200
	  else
	  	puts 'else'
	  	#render :nothing => true, :status => 500
	  end
	end
end
