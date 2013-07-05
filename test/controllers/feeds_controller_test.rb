require 'test_helper'

describe FeedsController do

	before :each do
		@user = create :user
		@admin = create :admin
		@asker = create :asker
		@asker.followers << @user	

		@question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)
		@publication = create(:publication, question: @question, asker: @asker)
		@question_post = create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)		
	end

	describe 'user answers question' do
		before :each do 
			Capybara.current_driver = :selenium
			login_as(@user, :scope => :user)	
			visit "/feeds/#{@asker.id}"
			post_elmnt = page.find(".post[post_id=\"#{@question_post.id}\"]")
			post_elmnt.click
			post_elmnt.all('.answers h3').first.click
			post_elmnt.all('.tweet_button').first.click
			page.find(".conversation[asker_id=\"#{@asker.id}\"] .subsidiary.answered")
		end
		
		it 'creates user post' do
			user_response = @user.posts.where(intention: 'respond to question').first
			user_response.in_reply_to_post_id.must_equal @question_post.id
		end

		it 'responds to user post' do
			grade_post = @asker.posts.where(intention: 'grade').first
			grade_post.in_reply_to_user_id.must_equal @user.id
		end
	end
end