require 'test_helper'

describe Moderation do	

	before :each do 
		ActiveRecord::Base.observers.enable :post_moderation_observer, :question_moderation_observer

		@user = create(:user, twi_user_id: 1, role: 'user')
		@moderator = create(:user, twi_user_id: 1, role: 'moderator')
		login_as(@moderator, :scope => :user)

		@asker = create(:asker)
		@user = create(:user, twi_user_id: 1)

		@asker.followers << [@user, @moderator]

		@question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)		
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

		@initial_question_dm = create(:dm, :initial_question_dm, user_id: @asker.id, question: @question)
		@conversation = create(:conversation, post: @initial_question_dm)
		@initial_question_dm.update_attributes conversation: @conversation
		@dm_answer = create :dm, 
			user: @user, 
			requires_action: true, 
			in_reply_to_post_id: @initial_question_dm.id,
			in_reply_to_user_id: @asker.id,
			in_reply_to_question_id: @question.id,
			conversation: @conversation

		@dm_from_asker = create(:dm, user_id: @asker.id, conversation: @conversation)
		@dm_reply = create :dm, 
			user: @user, 
			requires_action: true, 
			in_reply_to_post_id: @dm_from_asker.id,
			in_reply_to_user_id: @asker.id,
			conversation: @conversation		
		@qm_consensus_count = 2
	end

	describe 'observer' do
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

		describe 'triggers response' do
			describe 'on posts' do
				describe 'if greater than one moderation and greater than noob and consensus' do
					describe "for public response" do
						it 'as correct' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
							create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
							@post.reload.correct.must_equal true
							Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
						end

						it 'as incorrect' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
							create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
							@post.reload.correct.must_equal false
							Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
						end

						it 'as tell' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
							create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
							@post.reload.correct.must_equal false
							@response_post = Post.where(in_reply_to_post_id: @post.id, intention: 'grade').first
							@response_post.wont_be_nil
							@response_post.text.include?("I was looking for").must_equal true
						end

						it 'as hide' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
							create(:post_moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							create(:post_moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
							@post.reload.correct.must_be_nil
							Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
						end

						after :each do 
							@post.requires_action.must_equal false
							@post.moderation_trigger_type_id.must_equal 1
						end					
					end

					describe "for private response" do
						it 'as correct' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
							create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @dm_answer.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @dm_answer.id)

							@dm_answer.reload.requires_action.must_equal false
							@dm_answer.correct.must_equal true
							@dm_answer.moderation_trigger_type_id.must_equal 1
							Delayed::Worker.new.work_off
							Post.where(in_reply_to_user_id: @dm_answer.user_id, intention: 'grade').count.must_equal 1
						end
					end
				end

				describe 'if at least one moderation from super mod' do
					it 'as correct' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
						@post.reload.correct.must_equal true
						Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1

						@post.requires_action.must_equal false
						@post.moderation_trigger_type_id.must_equal 2
					end

					it 'as incorrect' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
						@post.reload.correct.must_equal false
						Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1

						@post.requires_action.must_equal false
						@post.moderation_trigger_type_id.must_equal 2
					end					

					it 'as tell' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
						@post.reload.correct.must_equal false
						@response_post = Post.where(in_reply_to_post_id: @post.id, intention: 'grade').first
						@response_post.wont_be_nil
						@response_post.text.include?("I was looking for").must_equal true

						@post.requires_action.must_equal false
						@post.moderation_trigger_type_id.must_equal 2
					end

					it 'as hide' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:post_moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
						@post.reload.correct.must_be_nil
						Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0

						@post.requires_action.must_equal false
						@post.moderation_trigger_type_id.must_equal 2
					end

					describe "for private response" do
						it 'as correct' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
							@dm_answer.reload.correct.must_be_nil
							create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @dm_answer.id)
							Post.where(in_reply_to_post_id: @dm_answer.id, intention: 'grade').count.must_equal 0

							@dm_answer.reload.requires_action.must_equal false
							@dm_answer.correct.must_equal true
							@dm_answer.moderation_trigger_type_id.must_equal 2
							Delayed::Worker.new.work_off
							Post.where(in_reply_to_user_id: @dm_answer.user_id, intention: 'grade').count.must_equal 1
						end
					end
				end

				describe 'if three moderations and partial consensus and at least one consensus mod above noob' do
					it 'as correct' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
						2.times do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
						end

						@post.reload.correct.must_equal true
						Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
						# Post.where(in_reply_to_post_id: @post.id, intention: 'grade').first.moderation_trigger_type_id.must_equal 2
					end			

					it 'as incorrect' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
						2.times do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
						end

						@post.reload.correct.must_equal false
						Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1					
					end		

					it 'as tell' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
						2.times do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
						end

						@post.reload.correct.must_equal false
						Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1					
					end		

					it 'as hide' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
						2.times do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							create(:post_moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
						end

						@post.reload.correct.must_be_nil
						Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
					end	

					after :each do 
						@post.requires_action.must_equal false
						@post.moderation_trigger_type_id.must_equal 3
					end									
				end

				describe 'and accepts/rejects other moderations' do
					describe 'if greater than one moderation and greater than noob and consensus' do
						it 'by marking consensus moderations as accepted' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
							moderation1 = create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							moderation2 = create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
							moderation1.reload.accepted.must_equal true
							moderation2.reload.accepted.must_equal true
						end
					end

					describe 'if at least one moderation from super mod' do
						it 'by marking supermod moderation as accepted' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
							moderation = create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
							moderation.reload.accepted.must_equal true
						end

						it 'by marking non-supermod agreeing moderations as accepted' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
							moderation = create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
							moderation2 = create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
							
							moderation.reload.accepted.must_equal true
							moderation2.reload.accepted.must_equal true
						end

						it 'by marking non-supermod non-agreeing moderations as rejected' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
							moderation = create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
							moderation2 = create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
							
							moderation.reload.accepted.must_equal false
							moderation2.reload.accepted.must_equal true
						end					
					end

					describe 'if three moderations and partial consensus and at least one consensus mod above noob' do
						it 'by marking consensus moderations as accepted, non-consensus as rejected' do
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
							moderation = create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							moderation2 = create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
							moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
							moderation3 = create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)

							moderation.reload.accepted.must_equal true
							moderation2.reload.accepted.must_equal false
							moderation3.reload.accepted.must_equal true
						end
					end				
				end
			end

			describe 'on questions' do
				describe 'and triggers response' do
					before :each do 
						@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
					end

					it 'as publishable by consensus' do
						@ugc_question.publishable.must_equal nil
						@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id) }
						@ugc_question.reload.publishable.must_equal true
					end

					it 'as needs edits by consensus' do
						@ugc_question.reload.needs_edits.must_equal nil
						create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id) }
						@ugc_question.reload.needs_edits.must_equal true
					end	
				end

				describe 'and accepts/rejects other moderations' do
					before :each do 
						@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
						@supermod = create(:moderator, moderator_segment: 4, lifecycle_segment: 4)
						30.times { create(:question_moderation, accepted: true, user_id: @supermod.id, question_id: @question.id) }
					end

					it 'wont accept/reject moderations on consensus' do
						@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id) }
						@ugc_question.reload.needs_edits.must_equal true
						@ugc_question.question_moderations.each { |qm| qm.accepted.must_equal nil } 
					end

					it 'wont accept/reject moderations when supermod votes before consensus' do
						(@qm_consensus_count - 1).times { create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id) }
						create(:question_moderation, user_id: @supermod.id, type_id: 11, question_id: @ugc_question.id)
						@ugc_question.question_moderations.each { |qm| qm.accepted.must_equal nil } 
					end

					it 'accepts publishable + rejects non-publishable when accepted by supermod after consensus' do
						moderation = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						moderation2 = create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id)
						moderation3 = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						moderation4 = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						supermod = create(:question_moderation, user_id: @supermod.id, type_id: 7, question_id: @ugc_question.id)

						moderation.reload.accepted.must_equal true
						moderation2.reload.accepted.must_equal false
						moderation3.reload.accepted.must_equal true
						moderation4.reload.accepted.must_equal true
						supermod.reload.accepted.must_equal true
					end

					it 'rejects publishable + accepts non-publishable when rejected by supermod after consensus' do
						moderation = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						moderation2 = create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id)
						moderation3 = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						moderation4 = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						supermod = create(:question_moderation, user_id: @supermod.id, type_id: 11, question_id: @ugc_question.id)
						
						moderation.reload.accepted.must_equal false
						moderation2.reload.accepted.must_equal true
						moderation3.reload.accepted.must_equal false
						moderation4.reload.accepted.must_equal false
						supermod.reload.accepted.must_equal true
					end

					it 'sets question status to published when accepted by supermod' do
						@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id) }
						create(:question_moderation, user_id: @supermod.id, type_id: 7, question_id: @ugc_question.id)
						@ugc_question.reload.status.must_equal(1)
					end

					it 'sets question status to rejected when rejected by supermod' do
						@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id) }
						create(:question_moderation, user_id: @supermod.id, type_id: 11, question_id: @ugc_question.id)
						@ugc_question.reload.status.must_equal(-1)
					end

					describe 'and updates feedback attributes' do
						it 'when needs edits and supermod agrees' do
							@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id) }
							@ugc_question.reload.needs_edits.must_equal true
							create(:question_moderation, user_id: @supermod.id, type_id: 11, question_id: @ugc_question.id)
							@ugc_question.reload.needs_edits.must_equal true
						end

						it 'when publishable and supermod agrees' do
							@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id) }
							@ugc_question.reload.publishable.must_equal true
							create(:question_moderation, user_id: @supermod.id, type_id: 7, question_id: @ugc_question.id)
							@ugc_question.reload.publishable.must_equal true
						end

						it 'when needs edits and supermod disagrees' do 
							@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id) }
							@ugc_question.reload.needs_edits.must_equal true
							create(:question_moderation, user_id: @supermod.id, type_id: 7, question_id: @ugc_question.id)
							@ugc_question.reload.needs_edits.must_equal nil
						end

						it 'when publishable and supermod disagrees' do
							@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id) }
							@ugc_question.reload.publishable.must_equal true
							create(:question_moderation, user_id: @supermod.id, type_id: 11, question_id: @ugc_question.id)
							@ugc_question.reload.publishable.must_equal nil
						end
					end
				end		
			end
		end

		describe "won't trigger response" do
			describe 'on posts' do
				it 'if less than one moderation' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					@post.reload.requires_action.must_equal true
					@post.correct.must_equal nil
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
				end

				it 'if no consensus' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)				
					@post.reload.requires_action.must_equal true
					@post.correct.must_equal nil
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
				end

				it 'if no moderator above noob' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 2)
					create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)				
					@post.reload.requires_action.must_equal true
					@post.correct.must_equal nil
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0		
				end

				it 'if moderators don\'t know how to handle' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
					create(:post_moderation, user_id: moderator.id, type_id: 6, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 2)
					create(:post_moderation, user_id: moderator.id, type_id: 6, post_id: @post.id)
					@post.reload.requires_action.must_equal true
					@post.correct.must_equal nil
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0		
				end

				it 'and won\'t accept/reject moderations' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
					moderation1 = create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					moderation2 = create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					moderation3 = create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
					
					moderation1.reload.accepted.must_equal nil
					moderation2.reload.accepted.must_equal nil
					moderation3.reload.accepted.must_equal nil
				end			

				it "if consensus and post was already graded" do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)				
					@post.reload.requires_action.must_equal false
					@post.correct.must_equal true
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1

					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
				end

				it "if consensus and post was hidden" do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:post_moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:post_moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)				
					@post.reload.requires_action.must_equal false
					@post.correct.must_equal nil
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0

					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)		
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
				end		

				it "if supermod moderates and post was already graded" do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)				
					@post.reload.requires_action.must_equal false
					@post.correct.must_equal true
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1

					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
				end

				it "if supermod moderates and post was hidden" do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:post_moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
					create(:post_moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)				
					@post.reload.requires_action.must_equal false
					@post.correct.must_equal nil
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0

					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
					create(:post_moderation, user_id: moderator.id, type_id: 1, post_id: @post.id)		
					Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
				end
			end

			describe 'on questions' do
				before :each do 
					@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
				end

				it 'if less than one moderation' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 11, question_id: @ugc_question.id)
					@ugc_question.reload.status.must_equal 0
					@ugc_question.needs_edits.must_equal nil
				end

				it 'if no consensus' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 7, question_id: @ugc_question.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 11, question_id: @ugc_question.id)					
					@ugc_question.reload.status.must_equal 0
					@ugc_question.needs_edits.must_equal nil
					@ugc_question.publishable.must_equal nil
				end
				
				# it "if consensus and question was already approved" do
				# 	moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				# 	create(:question_moderation, user_id: moderator.id, type_id: 11, question_id: @ugc_question.id)
				# 	@ugc_question.update_attribute :status, 1
				# 	@ugc_question.reload.needs_edits.must_equal nil

				# 	moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				# 	create(:question_moderation, user_id: moderator.id, type_id: 11, question_id: @ugc_question.id)					
				# 	@ugc_question.reload.status.must_equal 1
				# 	@ugc_question.needs_edits.must_equal nil
				# end

				# it "if consensus and question was already rejected" do
				# 	moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				# 	create(:question_moderation, user_id: moderator.id, type_id: 11, question_id: @ugc_question.id)
				# 	@ugc_question.update_attribute :status, -1

				# 	moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
				# 	create(:question_moderation, user_id: moderator.id, type_id: 11, question_id: @ugc_question.id)					
				# 	@ugc_question.reload.status.must_equal -1
				# 	@ugc_question.needs_edits.must_equal nil					
				# end

				# it "if supermod moderates and post was approved" do
				# 	@ugc_question.update_attribute :status, 1
				# 	moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 6)
				# 	create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)					
				# 	@ugc_question.reload.status.must_equal 1
				# 	@ugc_question.bad_answers.must_equal nil		
				# end

				# it "if supermod moderates and post was rejected" do
				# 	@ugc_question.update_attribute :status, -1
				# 	moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 6)
				# 	create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)					
				# 	@ugc_question.reload.status.must_equal -1
				# 	@ugc_question.bad_answers.must_equal nil		
				# end
			end
		end
	end	
end