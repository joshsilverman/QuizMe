require 'test_helper'

describe EmailAskersController do
	let(:course) {create(:course, :with_lessons)}

	before :each do
		@email_asker = course.askers.first.becomes(EmailAsker)
		@emailer = create(:emailer, twi_user_id: 1)
		@email_asker.followers << @emailer		
		@question = @email_asker.questions.first
		@publication = create(:publication, question_id: @question.id)

		@strategy = [1, 2, 4, 8]
		@emailer_response = create(:post, text: 'the correct answer, yo', user_id: @emailer.id, in_reply_to_user_id: @email_asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)
		@emailer_response.update_attributes created_at: (@strategy.first + 1).days.ago, correct: true
		@emailer.update_attributes last_answer_at: @emailer_response.created_at, last_interaction_at: @emailer_response.created_at, activity_segment: nil

		Delayed::Worker.delay_jobs = false
		Asker.reengage_inactive_users strategy: @strategy
		@email_question_post = @email_asker.posts.where(intention: 'reengage inactive', in_reply_to_user_id: @emailer.id).first

		@next_question = @email_question_post.question
		text = "#{@next_question.answers.correct.text}\r\n#{URL}/questions/#{@next_question.id}?s=email&lt=reengage&c=QuizMeBio&t=scottie"
		@email_answer_params = {to: @email_asker.email, from: @emailer.email, text: text}
		post "save_private_response", @email_answer_params
		@email_answer = @emailer.posts.where(in_reply_to_user_id: @email_asker.id).last
		@email_response_to_answer = @email_asker.posts.where(in_reply_to_user_id: @emailer.id, intention: 'grade').first
	end

	describe 'asks a question' do
    it 'and includes a link to the original video' do
      ActionMailer::Base.deliveries.first.body.raw_source.include?("Watch the full video at #{@question.resource_url}")
    end    
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

		describe 'and responds' do
      it 'includes a followup question on grade' do
        text = "#{@question.answers.correct.text}\r\n#{URL}/questions/#{@question.id}?s=email&lt=reengage&c=QuizMeBio&t=scottie"
        post "save_private_response", {to: @email_asker.email, from: @emailer.email, text: text}
        ActionMailer::Base.deliveries.last.body.raw_source.include?("Next question:")
      end		
    end
	end

	describe 'attempts to grade and send reply' do
		it 'successfully detects question' do
			@email_answer.in_reply_to_question_id.wont_be_nil
		end

		it 'and succedes in autograding correct' do
			@email_answer.reload.autocorrect.must_equal true
		end

		it 'and succedes in sending' do
			@email_response_to_answer.wont_be_nil
		end

		# it 'and fails if format cannot be interpreted'
		# it 'and does not appear in moderations/manage on failure'
	end
end