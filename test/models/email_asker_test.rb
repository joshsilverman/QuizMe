require 'minitest_helper'

describe EmailAsker do	
	before :each do
		@asker = create(:asker)
		@emailer = create(:emailer, twi_user_id: 1)
		@asker.followers << @emailer		
		@question = create(:question, created_for_asker_id: @asker.id, status: 1)		
		@publication = create(:publication, question_id: @question.id)
		@question_status = create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)		

		@strategy = [1, 2, 4, 8]
		@emailer_response = create(:post, text: 'the correct answer, yo', user_id: @emailer.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)
		@emailer_response.update_attributes created_at: (@strategy.first + 1).days.ago, correct: true
		@emailer.update_attributes last_answer_at: @emailer_response.created_at, last_interaction_at: @emailer_response.created_at, activity_segment: nil
		create(:post, in_reply_to_user_id: @asker.id, correct: true, interaction_type: 2, in_reply_to_question_id: @question.id)

		Delayed::Worker.delay_jobs = false
		Asker.reengage_inactive_users strategy: @strategy
	end

	it 'is not the default communication preference' do
		User.create.communication_preference.must_equal 1
	end

	describe 'public send' do
		it 'degrades to private send' do
			@asker.posts.where(intention: 'reengage inactive', in_reply_to_user_id: @emailer).first.interaction_type.must_equal 5
		end
	end

	describe 'private send' do
		it 'is used when communication preference is set for email' do
			@emailer.communication_preference.must_equal 2
			@asker.posts.where(intention: 'reengage inactive', in_reply_to_user_id: @emailer.reload).first.interaction_type.must_equal 5
		end

		it 'is not used when communication preference is set for Twitter' do
			@emailer.update_attributes communication_preference: 1
			Timecop.travel 3.days
			Asker.reengage_inactive_users strategy: @strategy
			posts = @asker.posts.where(intention: 'reengage inactive', in_reply_to_user_id: @emailer)
			posts.count.must_equal 2
			posts.last.interaction_type.must_equal 2
			ActionMailer::Base.deliveries.count.must_equal 1
		end

		it 'will cause email delivery' do
			ActionMailer::Base.deliveries.wont_be_empty
		end

		it 'sends a clickable link'
	end
end