require 'minitest_helper'

describe ModerationsController do

	before :each do
		@user = create(:user, twi_user_id: 1, role: 'user')
		@moderator = create(:user, twi_user_id: 1, role: 'moderator')
		login_as(@moderator, :scope => :user)

		@wisr_asker = create(:asker, id: 8765)
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
	end

	describe 'manage' do
		before :each do
			visit '/moderations/manage'
		end

		describe 'posts' do
			it 'displays mention for moderation' do
				page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
			end

			it 'displays dm for moderation' do
				page.all(".post[post_id=\"#{@dm_answer.id}\"]").count.must_equal 1
			end

			it 'only if in reply to post has question' do
				page.all(".post[post_id=\"#{@dm_reply.id}\"]").count.must_equal 0
			end

			it 'wont display graded posts with consensus' do
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

			it 'displays twice-moderated posts without consensus to > noob moderators' do
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

			it 'wont display posts with more than two grades' do
				[1, 2, 3].each do |type_id|
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
					create(:post_moderation, user_id: moderator.id, post: @post, type_id: type_id)
					@post.reload
				end

				visit '/moderations/manage'
				page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0			
			end

			it 'displays post without displaying admin hidden posts' do
				page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
				@post.update_attributes requires_action: false
				visit '/moderations/manage'
				page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0
			end

			it 'displays post without displaying previous moderated by user posts' do
				page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
				@post.post_moderations << create(:post_moderation, user_id: @moderator.id, post: @post)
				visit '/moderations/manage'
				page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0
			end

			it 'displays only askers user follow' do
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

			describe 'filter' do
				before :each do 
					@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
				end

				it "doesn't display questions to unqualified users" do
					visit '/moderations/manage'
					page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
				end

				it 'displays questions for moderation if lifecycle_segment > regular' do
					@moderator.update_attribute :moderator_segment, 3
					5.times { @moderator.questions << create(:question, status: 1) }
					@moderator.update_attribute :lifecycle_segment, 3
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0

					@moderator.update_attribute :lifecycle_segment, 4
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
				end

				it 'displays questions for moderation if moderator_segment > noob' do
					@moderator.update_attribute :lifecycle_segment, 4
					@moderator.update_attribute :moderator_segment, 2
					
					5.times { @moderator.questions << create(:question, status: 1) }
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0

					@moderator.update_attribute :moderator_segment, 4
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
				end

				it 'displays questions for moderation if has written enough questions' do
					@moderator.update_attribute :moderator_segment, 3
					@moderator.update_attribute :lifecycle_segment, 4
					5.times do |i|
						@moderator.questions << create(:question, status: 1)
						visit '/moderations/manage'
						page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal (i < 4 ? 0 : 1)
					end
				end
			end

			describe 'manage' do
				before :each do 
					@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
					5.times { @moderator.questions << create(:question, status: 1) }
					@moderator.update_attribute :lifecycle_segment, 4
					@moderator.update_attribute :moderator_segment, 3
				end

				it 'wont display questions already moderated by the user' do
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
					@ugc_question.question_moderations << create(:question_moderation, user_id: @moderator.id, question: @ugc_question, type_id: 10)
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
				end

				it 'wont display questions that are already decided' do 
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1

					@ugc_question.update_attribute :moderation_trigger_type_id, 1

					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
				end

				it 'displays questions with multiple moderations from only one user' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 10)
					@ugc_question.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 9)
					@ugc_question.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 8)					
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
				end

				it 'displays twice-moderated questions without consensus' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 10)
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.reload.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 9)

					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1	

					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.reload.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 9)

					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
				end

				it 'displays questions until consensus' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 7)
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.reload.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 8)
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.reload.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 9)
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.reload.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 10)

					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1
					
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.reload.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 7)
					
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
				end

				it 'wont display questions with consensus' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 8)
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 1

					moderator = create(:user, twi_user_id: 1, role: 'moderator')
					@ugc_question.reload.question_moderations << create(:question_moderation, user_id: moderator.id, question: @ugc_question, type_id: 8)
					visit '/moderations/manage'
					page.all(".post[question_id=\"#{@ugc_question.id}\"]").count.must_equal 0
				end

				it 'wont display already approved/rejected questions' do
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

				it 'displays question from only askers that the user follows' do
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
			end
		end


		describe 'moderation' do
			before :each do
				Capybara.current_driver = :selenium
				@admin = create(:user, twi_user_id: 1, role: 'admin')
				login_as @admin
			end

			describe 'posts' do
				describe 'correct grade' do
					before :each do
						2.times do
							moderator = create(:user, twi_user_id: 1, role: 'moderator')
							create(:post_moderation, user_id: moderator.id, post: @post)
							@moderation = create(:post_moderation, user_id: moderator.id, type_id: 1, post: @post)
							@moderation.accepted.must_equal nil
						end
						visit '/feeds/manage?filter=moderated'
					end

					it 'is accepted when admin agrees' do
						page.find('.quick-reply-yes').click
						# sleep 200
						page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
						@moderation.reload.accepted.must_equal true
					end

					it 'is rejected when admin disagrees' do
						page.find('.quick-reply-no').click
						page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
						@moderation.reload.accepted.must_equal false
					end
				end

				it 'public tell is accepted when admin agrees' do
					2.times do
						moderator = create(:user, twi_user_id: 1, role: 'moderator')
						create(:post_moderation, user_id: moderator.id, post: @post)
						@moderation = create(:post_moderation, user_id: moderator.id, type_id: 3, post: @post)
						@moderation.accepted.must_equal nil
					end
					visit '/feeds/manage?filter=moderated'
					page.find('.quick-reply-tell').click
					page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
					@moderation.reload.accepted.must_equal true
				end

				it 'private tell is accepted when admin agrees' do
					2.times do
						moderator = create(:user, twi_user_id: 1, role: 'moderator')
						create(:post_moderation, user_id: moderator.id, post: @dm_answer)
						@moderation = create(:post_moderation, user_id: moderator.id, type_id: 3, post: @dm_answer)
						@moderation.accepted.must_equal nil
					end
					visit '/feeds/manage?filter=moderated'
					page.find('.quick-reply-tell').click
					page.find(".conversation.dim .post[post_id=\"#{@dm_answer.id}\"]").visible?.must_equal true
					Delayed::Worker.new.work_off
					@asker.posts.where(in_reply_to_user_id: @user.id, intention: 'grade').count.must_equal 1
				end

				it 'hide is accepted when admin agrees' do
					2.times do
						moderator = create(:user, twi_user_id: 1, role: 'moderator')
						create(:post_moderation, user_id: moderator.id, post: @post)
						@moderation = create(:post_moderation, user_id: moderator.id, type_id: 5, post: @post)
						@moderation.accepted.must_equal nil
					end
					visit '/feeds/manage?filter=moderated'
					page.find('.btn-hide').click
					page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
					@moderation.reload.accepted.must_equal true
				end

				it 'yes is rejected when admin hides' do
					2.times do
						moderator = create(:user, twi_user_id: 1, role: 'moderator')
						create(:post_moderation, user_id: moderator.id, post: @post)
						@moderation = create(:post_moderation, user_id: moderator.id, type_id: 1, post: @post)
						@moderation.accepted.must_equal nil
					end
					visit '/feeds/manage?filter=moderated'
					page.find('.btn-hide').click
					page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
					@moderation.reload.accepted.must_equal false
				end
			end

			# describe 'questions' do
			# 	it 'moderation is accepted when admin agrees'
			# 	it 'moderation is rejected when admin disagrees'
			# end
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
			@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
			5.times { @moderator.questions << create(:question, status: 1) }
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

		# it 'without duplicating moderation'
	end

	describe 'routing' do
		before :each do
			@moderator.update_attributes role: 'user'
			@mod_path = '/moderations/manage'
		end
		it 'gives access to new moderators' do
			visit @mod_path
			current_path.wont_equal @mod_path
		end

		it 'allows moderators access' do
			@moderator.update_attributes role: 'moderator'
			visit @mod_path
			current_path.must_equal @mod_path
		end
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
					end

					it 'as incorrect' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:post_moderation, user_id: moderator.id, type_id: 2, post_id: @post.id)
						@post.reload.correct.must_equal false
						Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 1
					end					

					it 'as tell' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:post_moderation, user_id: moderator.id, type_id: 3, post_id: @post.id)
						@post.reload.correct.must_equal false
						@response_post = Post.where(in_reply_to_post_id: @post.id, intention: 'grade').first
						@response_post.wont_be_nil
						@response_post.text.include?("I was looking for").must_equal true
					end

					it 'as hide' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:post_moderation, user_id: moderator.id, type_id: 5, post_id: @post.id)
						@post.reload.correct.must_be_nil
						Post.where(in_reply_to_post_id: @post.id, intention: 'grade').count.must_equal 0
					end

					after :each do 
						@post.requires_action.must_equal false
						@post.moderation_trigger_type_id.must_equal 2
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
				# NOTE: I decided not to test every trigger type every attribute as above
				describe 'and triggers response' do
					before :each do 
						@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
					end

					it 'as publishable by consensus' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						create(:question_moderation, user_id: moderator.id, type_id: 7, question_id: @ugc_question.id)
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
						create(:question_moderation, user_id: moderator.id, type_id: 7, question_id: @ugc_question.id)
						@ugc_question.reload.publishable.must_equal true
					end

					it 'as inaccurate by tiebreaker' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:question_moderation, user_id: moderator.id, type_id: 8, question_id: @ugc_question.id)
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:question_moderation, user_id: moderator.id, type_id: 9, question_id: @ugc_question.id)
						@ugc_question.reload.inaccurate.must_equal nil

						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 5)
						create(:question_moderation, user_id: moderator.id, type_id: 8, question_id: @ugc_question.id)
						@ugc_question.reload.inaccurate.must_equal true
					end

					it 'as ungrammatical by tiebreaker' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
						create(:question_moderation, user_id: moderator.id, type_id: 9, question_id: @ugc_question.id)
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
						create(:question_moderation, user_id: moderator.id, type_id: 7, question_id: @ugc_question.id)
						@ugc_question.reload.ungrammatical.must_equal nil

						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
						create(:question_moderation, user_id: moderator.id, type_id: 9, question_id: @ugc_question.id)
						@ugc_question.reload.ungrammatical.must_equal true
					end				

					it 'as having bad answers consensus' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 1)
						create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
						create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)
						@ugc_question.reload.bad_answers.must_equal true
					end

					it 'after trigger condition has been satisfied' do
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
						create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)
						create(:question_moderation, user_id: moderator.id, type_id: 9, question_id: @ugc_question.id)

						@ugc_question.reload.moderation_trigger_type_id.must_equal nil
						moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 3)
						create(:question_moderation, user_id: moderator.id, type_id: 9, question_id: @ugc_question.id)
						@ugc_question.reload.moderation_trigger_type_id.wont_be_nil
						
						create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)
						@ugc_question.reload.bad_answers.must_equal true
						@ugc_question.reload.ungrammatical.must_equal true
					end
				end

				describe 'and accepts/rejects other moderations' do
					before :each do 
						@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
						Capybara.current_driver = :selenium
						@admin = create(:user, twi_user_id: 1, role: 'admin')
						login_as @admin
					end

					it 'wont accept moderations before admin accepts/rejects' do
						10.times do
							moderation = create(:question_moderation, user_id: create(:moderator).id, type_id: [7, 8, 9, 10].sample, question_id: @ugc_question.id)
							@ugc_question.reload.question_moderations.select { |qm| !qm.accepted.nil? }.count.must_equal 0
						end
					end

					it 'accepts publishable + rejects non-publishable moderations when published by admin' do
						moderation = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						moderation2 = create(:question_moderation, user_id: create(:moderator).id, type_id: 8, question_id: @ugc_question.id)
						moderation3 = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						
						visit '/questions/manage'
						page.find('.btn-success').click
						sleep 1 # capybara isn't waiting for ajax to return...

						moderation.reload.accepted.must_equal true
						moderation2.reload.accepted.must_equal false
						moderation3.reload.accepted.must_equal true
					end

					it 'rejects publishable + accepts non-publishable when question rejected by admin' do
						moderation = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						moderation2 = create(:question_moderation, user_id: create(:moderator).id, type_id: 8, question_id: @ugc_question.id)
						moderation3 = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						
						visit '/questions/manage'
						page.find('.btn-danger').click
						sleep 1
						
						moderation.reload.accepted.must_equal false
						moderation2.reload.accepted.must_equal true
						moderation3.reload.accepted.must_equal false
					end

					it 'run properly accepts/rejects when admin changes mind' do
						moderation = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)
						moderation2 = create(:question_moderation, user_id: create(:moderator).id, type_id: 8, question_id: @ugc_question.id)
						moderation3 = create(:question_moderation, user_id: create(:moderator).id, type_id: 7, question_id: @ugc_question.id)

						visit '/questions/manage'
						page.find('.btn-danger').click
						sleep 1
						moderation.reload.accepted.must_equal false
						moderation2.reload.accepted.must_equal true
						moderation3.reload.accepted.must_equal false

						page.find('.btn-success').click
						sleep 1
						moderation.reload.accepted.must_equal true
						moderation2.reload.accepted.must_equal false	
						moderation3.reload.accepted.must_equal true					
					end					
				end
			end
		end

		describe 'won\'t trigger response' do
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

				# super mod doesn't know how to handle?
			end

			describe 'on questions' do
				before :each do 
					@ugc_question = create(:question, status: 0, created_for_asker_id: @asker.id, user_id: create(:user).id)
				end

				it 'if less than one moderation' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 8, question_id: @ugc_question.id)
					@ugc_question.reload.status.must_equal 0
					@ugc_question.inaccurate.must_equal nil
				end

				it 'if no consensus' do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 8, question_id: @ugc_question.id)
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 9, question_id: @ugc_question.id)					
					@ugc_question.reload.status.must_equal 0
					@ugc_question.inaccurate.must_equal nil
					@ugc_question.ungrammatical.must_equal nil
				end
				
				it "if consensus and question was already approved" do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)
					@ugc_question.update_attribute :status, 1

					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)					
					@ugc_question.reload.status.must_equal 1
					@ugc_question.bad_answers.must_equal nil
				end

				it "if consensus and question was already rejected" do
					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)
					@ugc_question.update_attribute :status, -1

					moderator = create(:user, twi_user_id: 1, role: 'moderator', moderator_segment: 4)
					create(:question_moderation, user_id: moderator.id, type_id: 10, question_id: @ugc_question.id)					
					@ugc_question.reload.status.must_equal -1
					@ugc_question.bad_answers.must_equal nil					
				end

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