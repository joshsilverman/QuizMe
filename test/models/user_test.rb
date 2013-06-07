require 'minitest_helper'

describe User do	
	before :each do 
		Rails.cache.clear

		@asker = create(:asker)
		@user = create(:user, twi_user_id: 1)

		@asker.followers << @user		

		@question = create(:question, created_for_asker_id: @asker.id, status: 1)		
		@publication = create(:publication, question_id: @question.id)
		@question_status = create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)		

		@user_response = create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)
	end

	describe "transitions" do
		describe 'lifecycle' do
			it 'between noob => superuser' do
				Timecop.travel(Time.now.beginning_of_week)
				5.times do
					@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
				end
				30.times do |i|
					@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true

					if i >= 28 
						@user.is_superuser?.must_equal true
					elsif i >= 14
						@user.is_pro?.must_equal true
					elsif i >= 7
						@user.is_advanced?.must_equal true
					else
						@user.is_interested?.must_equal true
					end

					Timecop.travel(Time.now + 1.day)
				end
			end
		end

		describe "moderation"
			before :each do
				@user = FactoryGirl.create(:user, twi_user_id: 1)
				@moderator = FactoryGirl.create(:user, twi_user_id: 1, role: 'moderator')
				@asker = FactoryGirl.create(:asker)
				@asker.followers << [@user, @moderator]

				@question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)		
				@publication = FactoryGirl.create(:publication, question: @question, asker: @asker)
				@post_question = FactoryGirl.create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)		
				@conversation = FactoryGirl.create(:conversation, post: @post_question, publication: @publication)
			end

			it 'segment between edger => super mod' do
				55.times do |i|
					post = FactoryGirl.create :post, 
						user: @user, 
						requires_action: true, 
						in_reply_to_post_id: @post_question.id,
						in_reply_to_user_id: @asker.id,
						in_reply_to_question_id: @question.id,
						interaction_type: 2, 
						conversation: @conversation
					@moderator.moderations << FactoryGirl.create(:moderation, type_id:1, accepted: true)

					if i > 50
						@moderator.is_super_mod?.must_equal true
					elsif i > 20
					elsif i > 10
					elsif i > 2
					elsif i > 0
					else
					end
				end
			end
		end
	end
end