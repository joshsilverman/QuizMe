require 'minitest_helper'

describe Asker do	
	before :each do 
		Rails.cache.clear

		@asker = FactoryGirl.create(:asker)
		@user = FactoryGirl.create(:user, twi_user_id: 1)
		@asker.followers << @user		

		@question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 1)		
		@publication = FactoryGirl.create(:publication, question_id: @question.id)
		@question_status = FactoryGirl.create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)		

		@user_response = FactoryGirl.create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)
	end

	describe "responds to user answer" do
		before :each do 
			@correct = [1, 2].sample == 1
			@correct_answer = FactoryGirl.create(:answer, correct: true, text: 'the correct answer', question_id: @question.id)
			@incorrect_answer = FactoryGirl.create(:answer, correct: false, text: 'the incorrect answer', question_id: @question.id)
		end

		it "with a post" do
			@asker.app_response @user_response, @correct
			@asker.posts.where("intention = 'grade' and in_reply_to_user_id = ?", @user.id).wont_be_empty
		end

		it "and marks the user's post as responded to" do 
			@asker.app_response @user_response, @correct
			@user_response.requires_action.must_equal false
		end

		it "and marks the user's post as correct/incorrect" do 
			@user_response.correct.must_be_nil
			@asker.app_response @user_response, @correct
			@user_response.correct.wont_be_nil
		end

		it "and quotes the right answer when incorrect" do
			app_response = @asker.app_response @user_response, false
			app_response.text.include?(@correct_answer.text).must_equal true
		end

		describe "from the manager" do
			it "and doesn't overwrite response text" do
				response_text = "You were so close!"
				app_response = @asker.app_response @user_response, @correct, response_text: response_text
				app_response.text.include?(response_text).must_equal true
			end

			it "and quotes the user's post when they are correct" do
				app_response = @asker.app_response @user_response, true, manager_response: true, quote_user_answer: true
				app_response.text.include?(@user_response.text).must_equal true
			end
		end
	end

	describe "reengages users" do
		before :each do
			@strategy = [1, 2, 4, 8]

			@user_response.update_attributes created_at: (@strategy.first + 1).days.ago, correct: true
			@user.update_attributes last_answer_at: @user_response.created_at, last_interaction_at: @user_response.created_at, activity_segment: nil

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
				@reengagement_post = FactoryGirl.create(:post, user_id: @asker.id, created_at: (@user_response.created_at + @strategy.first.days + 1.hour), in_reply_to_user_id: @user.id, intention: 'reengage inactive')
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
			# 		@user_response.update_attribute :in_reply_to_question_id, @question.id
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