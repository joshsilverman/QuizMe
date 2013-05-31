require 'minitest_helper'

describe ModerationsController do

	before :each do
		@user = FactoryGirl.create(:user, twi_user_id: 1, role: 'user')
		@moderator = FactoryGirl.create(:user, twi_user_id: 1, role: 'moderator')
		login_as(@moderator, :scope => :user)

		@wisr_asker = FactoryGirl.create(:asker, id: 8765)
		@asker = FactoryGirl.create(:asker)
		@user = FactoryGirl.create(:user, twi_user_id: 1)
		@asker.followers << [@user, @moderator]

		@question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)		
		@publication = FactoryGirl.create(:publication, question: @question, asker: @asker)
		@post_question = FactoryGirl.create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)		
		@conversation = FactoryGirl.create(:conversation, post: @post_question, publication: @publication)
		@post = FactoryGirl.create :post, 
			user: @user, 
			requires_action: true, 
			in_reply_to_post_id: @post_question.id,
			in_reply_to_user_id: @asker.id,
			in_reply_to_question_id: @question.id,
			interaction_type: 2, 
			conversation: @conversation
	end

	describe 'manage' do
		before :each do
			visit '/moderations/manage'
		end
		it 'displays post for moderation' do
			page.find(".post[post_id=\"#{@post.id}\"]").visible?.must_equal true
		end
		it 'displays post without displaying graded postsz' do
			2.times do
				moderator = FactoryGirl.create(:user, twi_user_id: 1, role: 'moderator')
				@post.moderations << FactoryGirl.create(:moderation, user_id: moderator.id)
			end
			page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0
		end
		it 'displays post without displaying hidden posts'
		it 'displays only askers user follow'
	end

	describe 'creates moderation' do
		it 'with correct type id'
		it 'without duplicating moderation'
		it 'only for askers user follow'
	end


	# describe "show" do

	# 	it "displays user activity after answer" do
	# 		visit "/feeds/#{@asker.id}"
	# 		page.find("#post_feed").visible?.must_equal true
	# 	end
	# end
end