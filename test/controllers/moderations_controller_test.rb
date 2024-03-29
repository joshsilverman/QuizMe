require 'test_helper'

describe ModerationsController do
	before :each do
		ActiveRecord::Base.observers.enable :post_moderation_observer, :question_moderation_observer
		
		@user = create(:user, twi_user_id: 1, role: 'user')
		@moderator = create(:moderator, twi_user_id: 1)
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
		@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
		@qm_consensus_count = 2
	end

	describe 'manage' do
		before :each do 
			visit '/moderations/manage'
		end

		describe 'displays' do
			describe 'posts' do
				before :each do 
					login_as @moderator
					visit '/moderations/manage'
				end

				it 'mention for moderation' do
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
				end

				it 'dm for moderation' do
					page.all(".post[post_id=\"#{@dm_answer.id}\"]").count.must_equal 1
				end

				it 'only if in reply to post has question' do
					page.all(".post[post_id=\"#{@dm_reply.id}\"]").count.must_equal 0
				end

				it 'unless graded with consensus' do
					3.times do |i|
						moderator = create(:user, twi_user_id: 1, role: 'moderator')
						@post.post_moderations << create(:post_moderation, user_id: moderator.id, post: @post, type_id: 1)
						visit '/moderations/manage'
						if i < 1
							page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
						else
							page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0
						end
					end
				end

				it 'twice-moderated without consensus to > noob moderators' do
					@moderator.update_attribute :moderator_segment, 1
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@post.post_moderations << create(:post_moderation, user_id: moderator.id, post: @post, type_id: 1)
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@post.post_moderations << create(:post_moderation, user_id: moderator.id, post: @post, type_id: 2)

					visit '/moderations/manage'
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0

					@moderator.update_attribute :moderator_segment, 3
					visit '/moderations/manage'
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1	

					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@post.post_moderations << create(:post_moderation, user_id: moderator.id, post: @post, type_id: 2)
					visit '/moderations/manage'
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0
				end

				it 'unless more than two grades' do
					[1, 2, 3].each do |type_id|
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						create(:post_moderation, user_id: moderator.id, post: @post, type_id: type_id)
						@post.reload
					end

					visit '/moderations/manage'
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0			
				end

				it 'unless hidden by admin' do
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
					@post.update_attributes requires_action: false
					visit '/moderations/manage'
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0
				end

				it 'unless previous moderated by user' do
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
					@post.post_moderations << create(:post_moderation, user_id: @moderator.id, post: @post)
					visit '/moderations/manage'
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0
				end

				it 'from only askers the user follows' do
					asker = create(:asker)
					asker.followers << [@user]
					question = create(:question, created_for_asker_id: asker.id, status: 1, user: @user)		
					publication = create(:publication, question: question, asker: asker)
					post_question = create(:post, user_id: asker.id, interaction_type: 1, question: question, publication: publication)		
					conversation = create(:conversation, post: post_question, publication: publication)
					post = create :post, 
						user: @user, 
						requires_action: true, 
						in_reply_to_post_id: post_question.id,
						in_reply_to_user_id: asker.id,
						in_reply_to_question_id: question.id,
						interaction_type: 2, 
						conversation: conversation
					visit '/moderations/manage'
					page.all(".post[post_id=\"#{post.id}\"]").count.must_equal 0
				end

				it 'solicits grades for posts with moderator_id' do 
					@post.update_attributes moderator_id: 2
					visit '/moderations/manage'
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
				end
			end

			describe 'questions' do
				before :each do 
					login_as @moderator
				end	
							
				it "unless user is unqualified" do
					visit '/moderations/manage'
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
				end

				it 'if lifecycle_segment > regular' do
					@moderator.update_attribute :moderator_segment, 3
					5.times { @moderator.questions << create(:question, status: 1, created_for_asker_id: @asker.id) }
					@moderator.update_attribute :lifecycle_segment, 3
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0

					@moderator.update_attribute :lifecycle_segment, 4
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
				end

				it 'if moderator_segment > noob' do
					@moderator.update_attribute :lifecycle_segment, 4
					@moderator.update_attribute :moderator_segment, 2
					
					5.times { @moderator.questions << create(:question, status: 1, created_for_asker_id: @asker.id) }
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0

					@moderator.update_attribute :moderator_segment, 4
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
				end

				it "not requiring edits to non-supermods" do
					@moderator.update(lifecycle_segment: 4, moderator_segment: 4)

					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1

					@ugc_question.update(publishable: true)
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
				end

				it "both in need of edits and not to supermods" do 
					@new_ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
					@ugc_question.update(publishable: true)

					@moderator.update(lifecycle_segment: 4, moderator_segment: 4)
					30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }

					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
					page.all(".post[question_id=\"#{@new_ugc_question.id}\"]").count.must_equal 1
				end		

				it "moderated but not edited by a supermod to other supermods" do
					@moderator.update(lifecycle_segment: 4, moderator_segment: 4)
					30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }
					create(:question_moderation, question_id: @ugc_question.id, type_id: 7, user_id: @moderator.id)

					@moderator2 = create(:moderator, lifecycle_segment: 4, moderator_segment: 4)
					@asker.followers << @moderator2
					30.times { create(:question_moderation, accepted: true, user_id: @moderator2.id, question_id: @question.id) }
					login_as @moderator2
					visit '/moderations/manage'
					page.find(".post[question_id=\"#{@ugc_question.id}\"]").visible?.must_equal true
				end

				it "unless requires edits and non supermod" do
					@moderator.update(lifecycle_segment: 4, moderator_segment: 4)
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1

					@ugc_question.update(needs_edits: true)
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
				end
				
				describe 'for users who are qualified' do
					before :each do 
						@moderator.update(lifecycle_segment: 4, moderator_segment: 3)
					end

					it 'unless already moderated by the user' do
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
						@ugc_question.question_moderations << create(:question_moderation, user_id: @moderator.id, question: @ugc_question, type_id: 10)
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
					end

					it 'unless already decided' do 
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1

						@ugc_question.update_attribute :moderation_trigger_type_id, 1

						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
					end

					it 'if multiple moderations from only one user' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator')
						@ugc_question.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 11)
						@ugc_question.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 11)					
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
					end

					it 'twice-moderated without consensus' do
						@ugc_question.question_moderations << create(:question_moderation, user_id: create(:moderator).id, question: @ugc_question, type_id: 11)
						@ugc_question.reload.question_moderations << create(:question_moderation, user_id: create(:moderator).id, question: @ugc_question, type_id: 7)

						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1	

						(@qm_consensus_count - 1).times { @ugc_question.reload.question_moderations << create(:question_moderation, user_id: create(:moderator).id, question: @ugc_question, type_id: 11) }

						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
					end

					it 'until consensus' do
						@ugc_question.question_moderations << create(:question_moderation, user_id: create(:moderator).id, question: @ugc_question, type_id: 11)
						@ugc_question.reload.question_moderations << create(:question_moderation, user_id: create(:moderator).id, question: @ugc_question, type_id: 7)

						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
						
						(@qm_consensus_count - 1).times { @ugc_question.reload.question_moderations << create(:question_moderation, user_id: create(:moderator).id, question: @ugc_question, type_id: 7) }
						
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
					end

					it 'unless consensus reached' do
						@ugc_question.question_moderations << create(:question_moderation, user_id: create(:moderator).id, question: @ugc_question, type_id: 11)
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1

						(@qm_consensus_count - 1).times { @ugc_question.reload.question_moderations << create(:question_moderation, user_id: create(:moderator).id, question: @ugc_question, type_id: 11) }
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
					end

					it 'unless already approved/rejected questions' do
						@ugc_question.update_attribute :status, 0
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1

						@ugc_question.update_attribute :status, 1
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0

						@ugc_question.update_attribute :status, -1
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0					
					end

					it 'from only askers that the user follows' do
						new_asker = create(:asker)
						@new_ugc_question = create(:question, status: 0, created_for_asker_id: new_asker.id, user_id: create(:user).id)
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
						page.all(".post[question_id=\"#{@new_ugc_question.id}\"]").count.must_equal 0

						@moderator.follows << new_asker
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
						page.all(".post[question_id=\"#{@new_ugc_question.id}\"]").count.must_equal 1					
					end

					describe 'supermod' do
						before :each do 
							Capybara.current_driver = :selenium
							login_as @moderator
						end
						
						it 'that are published, but need edits' do
							@moderator.update(lifecycle_segment: 4, moderator_segment: 4)
							30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }
							@ugc_question.update(status: 1, needs_edits: true)
							visit '/moderations/manage'
							page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
						end

						it 'when published and moderated as publishable' do 
							@moderator.update(lifecycle_segment: 4, moderator_segment: 4)
							30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }
							@ugc_question.update(status: 1, publishable: true)
							visit '/moderations/manage'
							page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1			
						end

						it 'unpublishes published questions if supermod rejects' do
							@moderator.update(lifecycle_segment: 4, moderator_segment: 4)
							30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }
							@ugc_question.update(status: 1, needs_edits: true)
							visit '/moderations/manage'
							post = page.find(".post[question_id=\"#{@ugc_question.id}\"]")
							post.click
							post.find(".btn-danger").click
							sleep 1
							@ugc_question.reload.status.must_equal(-1)
						end

						it 'after decided then edited by a supermod' do
							@ugc_question.update(needs_edits: true)
							visit '/moderations/manage'
							page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0

							@asker.followers << (@moderator2 = create(:moderator, lifecycle_segment: 4, moderator_segment: 4))
							30.times { create(:question_moderation, accepted: true, user_id: @moderator2.id, question_id: @question.id) }
							login_as @moderator2
							visit '/moderations/manage'
							post = page.find(".post[question_id=\"#{@ugc_question.id}\"]")
							post.click
							post.find(".btn-danger").click
							fill_in 'question_input', with: "new question this is?"
							page.find('#submit_question').click
							sleep 1

							login_as @moderator
							visit '/moderations/manage'
							page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
						end

						it 'unless supermod rejected and didnt provide edits' do
							@ugc_question.update(needs_edits: true)
							30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }

							visit '/moderations/manage'
							post = page.find(".post[question_id=\"#{@ugc_question.id}\"]")
							post.click
							post.find(".btn-danger").click
							page.find('.cancel').click

							@asker.followers << (@moderator2 = create(:moderator, lifecycle_segment: 4, moderator_segment: 4))
							30.times { create(:question_moderation, accepted: true, user_id: @moderator2.id, question_id: @question.id) }
							login_as @moderator2
							visit '/moderations/manage'
							page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
						end

						it 'unless is supermod, requires edits, and already voted' do
							30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }
							(@qm_consensus_count - 1).times { create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id) }
							create(:question_moderation, user_id: @moderator.id, type_id: 11, question_id: @ugc_question.id)
							visit '/moderations/manage'
							page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0

							@asker.followers << (@moderator2 = create(:moderator, lifecycle_segment: 4, moderator_segment: 4))
							30.times { create(:question_moderation, accepted: true, user_id: @moderator2.id, question_id: @question.id) }
							login_as @moderator2
							visit '/moderations/manage'
							page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
						end
					end
				end

				describe 'edit modal' do
					before :each do
						Capybara.current_driver = :selenium
						@moderator.update(lifecycle_segment: 4, moderator_segment: 4)
					end

					it 'only to supermods' do
						login_as @moderator
						visit '/moderations/manage'
						post = page.find(".post[question_id=\"#{@ugc_question.id}\"]")
						post.click
						post.find('.btn-danger').click
						page.find('#post_question_modal', visible: false).visible?.must_equal false
					
						@ugc_question.update(needs_edits: true)
						@moderator2 = create(:moderator, lifecycle_segment: 4, moderator_segment: 4)
						@asker.followers << @moderator2
						30.times { create(:question_moderation, accepted: true, user_id: @moderator2.id, question_id: @question.id) }
						login_as @moderator2
						visit '/moderations/manage'
						post = page.find(".post[question_id=\"#{@ugc_question.id}\"]")
						post.click
						post.find('.btn-danger').click
						page.find('#post_question_modal').visible?.must_equal true
					end

					it 'only for questions requiring edits' do
						@new_ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id, needs_edits: true)
						30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }
						login_as @moderator
						visit '/moderations/manage'
						post = page.find(".post[question_id=\"#{@new_ugc_question.id}\"]")
						post.click
						post.find(".btn-danger").click
						page.find('#post_question_modal').visible?.must_equal true
						page.find('#post_question_modal .cancel').click

						post = page.find(".post[question_id=\"#{@new_ugc_question.id}\"]")
						post.click
						post.find('.btn-danger').click
						page.find('#post_question_modal', visible: false).visible?.must_equal false
					end

					it 'sets question status to pending on edit' do
						@ugc_question.status.must_equal(0)
						30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }
						@qm_consensus_count.times { create(:question_moderation, user_id: create(:moderator).id, type_id: 11, question_id: @ugc_question.id) }
						# login_as @moderator
						visit '/moderations/manage'
						post = page.find(".post[question_id=\"#{@ugc_question.id}\"]")
						post.click
						post.find(".btn-danger").click
						sleep 1
						@ugc_question.reload.status.must_equal(-1)

						fill_in 'question_input', with: "new question this is?"
						page.find('#submit_question').click
						sleep 1
						@ugc_question.reload.status.must_equal(0)
					end
				end
			end
		end

		describe 'updates moderations for questions' do
			before :each do 
				Capybara.current_driver = :selenium
			end

			it 'marks previous moderations as inactive after question is edited' do
				@moderator.update(lifecycle_segment: 4, moderator_segment: 3)
				30.times { create(:question_moderation, accepted: true, user_id: @moderator.id, question_id: @question.id) }

				moderation1 = create(:question_moderation, user_id: create(:moderator).id, question_id: @ugc_question.id, type_id: 11)
				moderation2 = create(:question_moderation, user_id: create(:moderator).id, question_id: @ugc_question.id, type_id: 11)
				moderation3 = create(:question_moderation, user_id: create(:moderator).id, question_id: @ugc_question.id, type_id: 11)
				moderation1.active.must_equal(true) and moderation2.active.must_equal(true)
				
				login_as @moderator
				visit '/moderations/manage'
				post = page.find(".post[question_id=\"#{@ugc_question.id}\"]")
				post.click
				post.find(".btn-danger").click
				fill_in 'question_input', with: "new question this is?"
				page.find('#submit_question').click	
				sleep 1
				moderation1.reload.active.must_equal(false) and moderation2.reload.active.must_equal(false) and moderation3.reload.active.must_equal(false)
			end
		end
	end

	describe 'creates moderation' do
		it 'with correct type id for posts' do
		  Capybara.current_driver = :selenium # unfortunately must be manually inserted if you want a js driver
			visit '/moderations/manage'
			page.all(".conversation.dim .post[post_id=\"#{@post.id}\"]").count.must_equal 0
			post = page.find(".conversation .post[post_id=\"#{@post.id}\"]")
			post.click
			post.find('.quick-reply.btn-success').click
			page.find(".conversation.moderated .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
			@post.post_moderations[0].type_id.must_equal 1
		end

		it 'with correct type id for questions' do
			5.times { @moderator.questions << create(:question, status: 1, created_for_asker_id: @asker.id) }
			@moderator.update_attribute :lifecycle_segment, 4
			@moderator.update_attribute :moderator_segment, 3

		  Capybara.current_driver = :selenium
			visit '/moderations/manage'
			page.all(".conversation.dim .post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
			post = page.find(".conversation .post[question_id=\"#{@ugc_question.id}\"]")
			post.click
			post.find('.btn-success').click
			page.find(".conversation.moderated .post[question_id=\"#{@ugc_question.id}\"]").visible?.must_equal true
			@ugc_question.question_moderations[0].type_id.must_equal 7
		end
	end

	describe 'routing' do
		it 'gives access to new moderators' do
			@moderator.update_attributes role: 'user'

			get :manage
			response.status.must_equal 302
		end

		it 'allows moderators access' do
			@moderator.update_attributes role: 'moderator'

			get :manage
			response.status.must_equal 302
		end
	end
end

describe ModerationsController, "#count" do
  it "must return correct count of moderations" do
    user = create :user
    moderation = Moderation.create user_id: user.id

    get :count, user_id: user.id, format: :json

    response.body.must_equal('1')
  end
end