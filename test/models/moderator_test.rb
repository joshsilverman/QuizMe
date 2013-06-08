require 'minitest_helper'

describe Moderator do	
	before :each do 
		@user = create(:user, twi_user_id: 1)
		@moderator = create(:user, twi_user_id: 1, role: 'moderator')
		@asker = create(:asker)
		@asker.followers << [@user, @moderator]
		@question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)		
		@question.answers << create(:answer, correct: true)
		@publication = create(:publication, question: @question, asker: @asker)
		@post_question = create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)		
		@conversation = create(:conversation, post: @post_question, publication: @publication)
		@post = create :post, 
			user: @user, 
			requires_action: true, 
			in_reply_to_post_id: @post_question.id,
			in_reply_to_user_id: @asker.id,
			in_reply_to_question_id: @question.id,
			interaction_type: 2, 
			conversation: @conversation

		Delayed::Worker.new.work_off
	end

	describe 'new moderation' do
		describe 'triggers response' do
			it 'correct if greater than one moderation and greater than noob and consensus' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				@post.reload.requires_action.must_equal false
				@post.correct.must_equal true
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
			end

			it 'incorrect if greater than one moderation and greater than noob and consensus' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
				create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
				@post.reload.requires_action.must_equal false
				@post.correct.must_equal false
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
			end

			it 'tell if greater than one moderation and greater than noob and consensus' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
				create(:moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
				@post.reload.requires_action.must_equal false
				@post.correct.must_equal false
				@response_post = Post.where(in_reply_to_post_id: @post.id, intention: 'grade').first
				@response_post.wont_be_nil
				@response_post.text.include?("I was looking for").must_equal true
			end

			it 'hide if greater than one moderation and greater than noob and consensus' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
				create(:moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
				@post.reload.requires_action.must_equal false
				@post.correct.must_be_nil
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
			end

			it 'runif at least one moderation from super mod' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				@post.reload.requires_action.must_equal false
				@post.correct.must_equal true
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
			end

			describe 'and accepts/rejects other moderations' do
			end
		end
		describe 'won\'t trigger app response with early consenus' do
			it 'if less than one moderation'
			it 'if no consensus'
			it 'if no moderator above noob'
			it 'if moderators don\'t know how to handle'

			describe 'and won\'t accept/reject other' do
			end
		end

		it "won't sent multiple grades to user"
	end
end