require 'minitest_helper'

describe Asker do	
	before :each do 
		Rails.cache.clear
	end

	describe "reengages users" do
		before :each do
			@strategy = [1, 2, 4, 8]

			@asker = FactoryGirl.create(:asker)

			@question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 1)
			@publication = FactoryGirl.create(:publication, question_id: @question.id)
			@question_status = FactoryGirl.create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)

			@user = FactoryGirl.create(:user, twi_user_id: 1)
			@asker.followers << @user

			@answer = FactoryGirl.create(:post, user_id: @user.id, created_at: (@strategy.first + 1).days.ago, in_reply_to_user_id: @asker.id, correct: true, interaction_type: 2, in_reply_to_question_id: @question.id)
			@user.update_attributes last_answer_at: @answer.created_at, last_interaction_at: @answer.created_at, activity_segment: nil

			FactoryGirl.create(:post, in_reply_to_user_id: @asker.id, correct: true, interaction_type: 2, in_reply_to_question_id: @question.id)
		end

		it "with a post" do
			Asker.reengage_inactive_users strategy: @strategy
			Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).wont_be_empty
		end

		it "on the proper schedule" do 
			Asker.reengage_inactive_users strategy: @strategy
			intervals = []
			@strategy.each_with_index { |e, i| intervals << @strategy[0..i].sum }
			@strategy.sum.times do |i|
				Timecop.travel(Time.now + 1.day)
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where("user_id = ? and in_reply_to_user_id = ? and created_at > ?", @asker.id, @user.id, Time.now.beginning_of_day).wont_be_empty if intervals.include?(i + 2)
			end
		end

		it "that have answered a question" do
			Asker.reengage_inactive_users strategy: @strategy
			Post.answers.where(:user_id => @user).count.must_equal 1
		end	

		it "that are inactive" do
			Asker.reengage_inactive_users strategy: @strategy
			@user.posts.where("created_at > ?", @strategy.first.days.ago).count.must_equal 0
		end	

		it "from an asker that they are following" do
			@asker.followers.delete @user
			Asker.reengage_inactive_users strategy: @strategy
			Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).must_be_empty
		end

		describe "but not" do
			before :each do 
				@reengagement_post = FactoryGirl.create(:post, user_id: @asker.id, created_at: (@answer.created_at + @strategy.first.days + 1.hour), in_reply_to_user_id: @user.id, intention: 'reengage inactive')
			end

			it "if they've already been reengaged" do
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where("created_at > ?", @reengagement_post.created_at).where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).must_be_empty
			end
		end

		describe "with a question" do
			it "that has been approved" do
				@unapproved_question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 0)
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).first.question.status.must_equal 1
			end

			# describe "that hasn't been" do
			# 	before :each do
			# 		@new_question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 1)
			# 	end

			# 	it "that hasn't been answered before" do
			# 		@answer.update_attribute :in_reply_to_question_id, @question.id
			# 		Asker.reengage_inactive_users strategy: @strategy
			# 		Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).first.question_id.must_equal @new_question.id
			# 	end

			# 	it "that hasn't been asked before" do
			# 		@reengagement_post = FactoryGirl.create(:post, user_id: @asker.id, created_at: (@strategy.first + 5).days.ago, in_reply_to_user_id: @user.id, intention: 'reengage inactive', question_id: @question.id)
			# 		Asker.reengage_inactive_users strategy: @strategy
			# 		Post.reengage_inactive.where("created_at > ?", @reengagement_post.created_at).where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).first.question_id.must_equal @new_question.id		
			# 	end		
			# end	
		end				
	end
end