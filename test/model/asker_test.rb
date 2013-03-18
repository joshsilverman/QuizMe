require 'minitest_helper'

describe Asker do	
	before :each do 
		Rails.cache.clear
	end

	describe "reengages users" do
		before :each do
			@strategy = [3, 5, 7]

			@asker = FactoryGirl.create(:asker)
			@question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 1)
			@publication = FactoryGirl.create(:publication, question_id: @question.id)
			@question_status = FactoryGirl.create(:post, user_id: @asker.id, created_at: (@strategy.first - 2).days.ago, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)

			@user = FactoryGirl.create(:user, twi_user_id: 1)
			@asker.followers << @user

			@answer = FactoryGirl.create(:post, user_id: @user.id, created_at: (@strategy.first + 1).days.ago, in_reply_to_user_id: @asker.id, correct: true, interaction_type: 2)
			@user.update_attributes last_answer_at: @answer.created_at, last_interaction_at: @answer.created_at, activity_segment: nil
		end

		it "with a post" do
			Asker.reengage_inactive_users @strategy
			Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).wont_be_empty
		end

		it "that have answered a question" do
			Asker.reengage_inactive_users @strategy
			Post.answers.where(:user_id => @user).count.must_equal 1
		end	

		it "that are inactive" do
			Asker.reengage_inactive_users @strategy
			@user.posts.where("created_at > ?", @strategy.first.days.ago).count.must_equal 0
		end	

		describe "but not" do
			before :each do 
				@reengagement_post = FactoryGirl.create(:post, user_id: @asker.id, created_at: (@strategy.first - 1).days.ago, in_reply_to_user_id: @user.id, intention: 'reengage inactive')
			end

			it "if they've already been reengaged" do
				Asker.reengage_inactive_users @strategy
				Post.reengage_inactive.where("created_at > ?", @reengagement_post.created_at).where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).count.must_equal 0
			end
		end

		describe "with a question" do
			it "that has been approved" do
				Asker.reengage_inactive_users @strategy
				Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).first.question.status.must_equal 1
			end

			# describe "that hasn't been" do
			# 	before :each do
			# 		@new_question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 1)
			# 	end

			# 	it "that hasn't been answered before" do
			# 		@answer.update_attribute :in_reply_to_question_id, @question.id
			# 		Asker.reengage_inactive_users @strategy
			# 		Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).first.question_id.must_equal @new_question.id
			# 	end

			# 	it "that hasn't been asked before" do
			# 		@reengagement_post = FactoryGirl.create(:post, user_id: @asker.id, created_at: (@strategy.first + 5).days.ago, in_reply_to_user_id: @user.id, intention: 'reengage inactive', question_id: @question.id)
			# 		Asker.reengage_inactive_users @strategy
			# 		Post.reengage_inactive.where("created_at > ?", @reengagement_post.created_at).where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).first.question_id.must_equal @new_question.id		
			# 	end		
			# end	
		end				
	end
end