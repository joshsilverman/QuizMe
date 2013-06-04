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
			page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 1
		end

		it 'displays post without displaying graded posts' do
			2.times do
				moderator = FactoryGirl.create(:user, twi_user_id: 1, role: 'moderator')
				@post.moderations << FactoryGirl.create(:moderation, user_id: moderator.id)
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
			@post.moderations << FactoryGirl.create(:moderation, user_id: @moderator.id)
			visit '/moderations/manage'
			page.all(".post[post_id=\"#{@post.id}\"]").count.must_equal 0
		end

		it 'displays only askers user follow' do
			asker = FactoryGirl.create(:asker)
			asker.followers << [@user]
			question = FactoryGirl.create(:question, created_for_asker_id: asker.id, status: 1, user: @user)		
			publication = FactoryGirl.create(:publication, question: question, asker: asker)
			post_question = FactoryGirl.create(:post, user_id: asker.id, interaction_type: 1, question: question, publication: publication)		
			conversation = FactoryGirl.create(:conversation, post: post_question, publication: publication)
			post = FactoryGirl.create :post, 
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

		describe 'moderation' do
			before :each do
				Capybara.current_driver = :selenium
				@admin = FactoryGirl.create(:user, twi_user_id: 1, role: 'admin')
				login_as(@admin, :scope => :user)
			end
			
			describe 'correct grade' do
				before :each do
					2.times do
						moderator = FactoryGirl.create(:user, twi_user_id: 1, role: 'moderator')
						@post.moderations << FactoryGirl.create(:moderation, user_id: moderator.id)
						@post.moderations << @moderation = FactoryGirl.create(:moderation, user_id: moderator.id, type_id: 1)
						@moderation.accepted.must_equal nil
					end
					visit '/feeds/manage?filter=moderated'
				end

				it 'is accepted when admin agrees' do
					page.find('.quick-reply-yes').click
					page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
					@moderation.reload.accepted.must_equal true
				end

				it 'is rejected when admin disagrees' do
					page.find('.quick-reply-no').click
					page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
					@moderation.reload.accepted.must_equal false
				end
			end

			it 'tell is accepted when admin agrees' do
				2.times do
					moderator = FactoryGirl.create(:user, twi_user_id: 1, role: 'moderator')
					@post.moderations << FactoryGirl.create(:moderation, user_id: moderator.id)
					@post.moderations << @moderation = FactoryGirl.create(:moderation, user_id: moderator.id, type_id: 3)
					@moderation.accepted.must_equal nil
				end
				visit '/feeds/manage?filter=moderated'
				page.find('.quick-reply-tell').click
				page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
				@moderation.reload.accepted.must_equal true
			end

			it 'hide is accepted when admin agrees' do
				2.times do
					moderator = FactoryGirl.create(:user, twi_user_id: 1, role: 'moderator')
					@post.moderations << FactoryGirl.create(:moderation, user_id: moderator.id)
					@post.moderations << @moderation = FactoryGirl.create(:moderation, user_id: moderator.id, type_id: 5)
					@moderation.accepted.must_equal nil
				end
				visit '/feeds/manage?filter=moderated'
				page.find('.btn-hide').click
				page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
				@moderation.reload.accepted.must_equal true
			end

			it 'yes is rejected when admin hides' do
				2.times do
					moderator = FactoryGirl.create(:user, twi_user_id: 1, role: 'moderator')
					@post.moderations << FactoryGirl.create(:moderation, user_id: moderator.id)
					@post.moderations << @moderation = FactoryGirl.create(:moderation, user_id: moderator.id, type_id: 1)
					@moderation.accepted.must_equal nil
				end
				visit '/feeds/manage?filter=moderated'
				page.find('.btn-hide').click
				page.find(".conversation.dim .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
				@moderation.reload.accepted.must_equal false
			end
		end
	end

	describe 'creates moderation' do
		it 'with correct type id' do
		  Capybara.current_driver = :selenium # unfortunately must be manually inserted if you want a js driver
			visit '/moderations/manage'
			page.all(".conversation.dim .post[post_id=\"#{@post.id}\"]").count.must_equal 0
			page.find('.quick-reply.btn-success').click
			page.find(".conversation.moderated .post[post_id=\"#{@post.id}\"]").visible?.must_equal true
			@post.moderations[0].type_id.must_equal 1
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
end