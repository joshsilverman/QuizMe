class MentionsController < ApplicationController

	def index
		@orphans = Mention.where('post_id is null')
		@posts = current_acct.posts.where('question_id is not null and provider = "twitter"').order('created_at DESC').limit(25)
	end

	def update
		m = Mention.find(params[:mention_id])
		first = params[:first].match(/(true|t|yes|y|1)$/i) != nil
		correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil

		puts m.inspect
		if m
	  	m.update_attributes(:responded => true)
	  	Rep.create(:user_id => m.user_ud, :post_id => m.post_id, :correct => correct) if correct

	  	case correct
	  	when true
		  	stat = Stat.find_or_create_by_date_and_account_id(Date.today.to_s, m.post.account_id)
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

	def scores
		render :json => Account.get_top_scorers(params[:id])
	end
end
