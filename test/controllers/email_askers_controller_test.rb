require 'minitest_helper'

describe EmailAskersController do

	before :each do
		@email_asker = create(:email_asker)
		@emailer = create(:emailer, twi_user_id: 1)
		@email_asker.followers << @emailer		
		@question = create(:question, created_for_asker_id: @email_asker.id, status: 1)		
		@publication = create(:publication, question_id: @question.id)

		@strategy = [1, 2, 4, 8]
		@emailer_response = create(:post, text: 'the correct answer, yo', user_id: @emailer.id, in_reply_to_user_id: @email_asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)
		@emailer_response.update_attributes created_at: (@strategy.first + 1).days.ago, correct: true
		@emailer.update_attributes last_answer_at: @emailer_response.created_at, last_interaction_at: @emailer_response.created_at, activity_segment: nil

		Delayed::Worker.delay_jobs = false
		Asker.reengage_inactive_users strategy: @strategy
		@email_question_post = @email_asker.posts.where(intention: 'reengage inactive', in_reply_to_user_id: @emailer.id).first

		text = "the correct answer\r\nhttp://wisr.com/feeds/#{@email_asker.id}/#{@publication.id}?s=email&lt=reengage&c=QuizMeBio&t=scottie"
		@email_answer_params = {to: @email_asker.email, from: @emailer.email, text: text}
		post "save_private_response", @email_answer_params
		@email_answer = @emailer.posts.where(in_reply_to_user_id: @email_asker.id).last
		@email_response_to_answer = @email_asker.posts.where(in_reply_to_user_id: @emailer.id, intention: 'grade').first
	end

	describe 'saves private response' do
		it 'with correct to/from' do
			@email_answer.wont_be_nil
			@email_answer.in_reply_to_user.becomes(EmailAsker).must_equal @email_asker
		end

		it 'with correct conversation' do
			(conversation = @email_question_post.conversations.last).wont_be_nil
			@email_answer.conversation_id.must_equal conversation.id
		end

		it 'with correct in_reply_to_post' do
			@email_question_post.wont_be_nil
			@email_answer.in_reply_to_post_id.must_equal @email_question_post.id
		end
	end

	describe 'attempts to grade and send reply' do
		it 'successfully detects question' do
			@email_answer.in_reply_to_question_id.wont_be_nil
		end

		it 'run and succedes in autograding correct' do
			@email_answer.reload.autocorrect.must_equal true
		end

		it 'and succedes in sending' do
			@email_response_to_answer.wont_be_nil
		end

		it 'and fails if format cannot be interpreted'
		it 'and does not appear in moderations/manage on failure'
	end

end