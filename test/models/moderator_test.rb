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
			describe 'if greater than one moderation and greater than noob and consensus' do
				it 'as correct' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
					create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					@post.reload.requires_action.must_equal false
					@post.correct.must_equal true
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
				end

				it 'as incorrect' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
					create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
					@post.reload.requires_action.must_equal false
					@post.correct.must_equal false
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
				end

				it 'as tell' do
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

				it 'as hide' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
					create(:moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
					@post.reload.requires_action.must_equal false
					@post.correct.must_be_nil
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
				end
			end

			describe 'if at least one moderation from super mod' do
				it 'as correct' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
					create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					@post.reload.requires_action.must_equal false
					@post.correct.must_equal true
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
				end

				it 'as incorrect' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
					create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
					@post.reload.requires_action.must_equal false
					@post.correct.must_equal false
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
				end					

				it 'as tell' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
					create(:moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
					@post.reload.requires_action.must_equal false
					@post.correct.must_equal false
					@response_post = Post.where(in_reply_to_post_id: @post.id, intention: 'grade').first
					@response_post.wont_be_nil
					@response_post.text.include?("I was looking for").must_equal true
				end

				it 'as hide' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
					create(:moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
					@post.reload.requires_action.must_equal false
					@post.correct.must_be_nil
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
				end
			end

			describe 'and accepts/rejects other moderations' do
				describe 'if greater than one moderation and greater than noob and consensus' do
					it 'by marking consensus moderations as accepted' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						moderation1 = create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
						moderation2 = create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
						moderation1.reload.accepted.must_equal true
						moderation2.reload.accepted.must_equal true
					end
				end

				describe 'if at least one moderation from super mod' do
					it 'by marking supermod moderation as accepted' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						moderation = create(:moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
						moderation.reload.accepted.must_equal true
					end

					it 'by marking non-supermod agreeing moderations as accepted' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						moderation = create(:moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						moderation2 = create(:moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
						
						moderation.reload.accepted.must_equal true
						moderation2.reload.accepted.must_equal true
					end

					it 'by marking non-supermod non-agreeing moderations as rejected' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						moderation = create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						moderation2 = create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
						
						moderation.reload.accepted.must_equal false
						moderation2.reload.accepted.must_equal true
					end					
				end
			end
		end

		describe 'won\'t trigger response' do
			it 'if less than one moderation' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				@post.reload.requires_action.must_equal true
				@post.correct.must_equal nil
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
			end

			it 'if no consensus' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)				
				@post.reload.requires_action.must_equal true
				@post.correct.must_equal nil
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
			end

			it 'if no moderator above noob' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 2)
				create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)				
				@post.reload.requires_action.must_equal true
				@post.correct.must_equal nil
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0		
			end

			it 'if moderators don\'t know how to handle' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
				create(:moderation, user_id: moderator.id, type_id: 6, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 2)
				create(:moderation, user_id: moderator.id, type_id: 6, post_id: @post.id)
				@post.reload.requires_action.must_equal true
				@post.correct.must_equal nil
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0		
			end


			it 'and won\'t accept/reject moderations' do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
				moderation1 = create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				moderation2 = create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				moderation3 = create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				moderation1.reload.accepted.must_equal nil
				moderation2.reload.accepted.must_equal nil
				moderation3.reload.accepted.must_equal nil
			end			

			it "if consensus and post was already graded" do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)				
				@post.reload.requires_action.must_equal false
				@post.correct.must_equal true
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1

				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
			end

			it "if consensus and post was hidden" do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				create(:moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)				
				@post.reload.requires_action.must_equal false
				@post.correct.must_equal nil
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0

				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)		
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
			end		

			it "if supermod moderates and post was already graded" do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)				
				@post.reload.requires_action.must_equal false
				@post.correct.must_equal true
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1

				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
			end

			it "if supermod moderates and post was hidden" do
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				create(:moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
				create(:moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)				
				@post.reload.requires_action.must_equal false
				@post.correct.must_equal nil
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0

				moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
				create(:moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)		
				Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
			end

			# super mod doesn't know how to handle?
		end
	end
end