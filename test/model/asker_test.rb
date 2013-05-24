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

	end

	describe "responds to user answer" do
		before :each do 
			@user_response = FactoryGirl.create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)

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

			@user_response = FactoryGirl.create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)
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

	describe "relationships" do

		before :each do

			@new_user = FactoryGirl.create(:user, twi_user_id: 2)
		end

		describe "autofollow" do
			it "sends follows five days a week and during 18 hour periods" do
				Timecop.travel(Time.now.beginning_of_week)
				sent = 0
				7.times do |i|
					24.times do |j|
						sent += 1 if @asker.autofollow_count > 0
						Timecop.travel(Time.now + 1.hour)
					end
				end
				sent.must_equal 5 * 18
			end

			it "obeys maximum daily follow limit" do
				12.times { @asker.add_follow(FactoryGirl.create(:user), 2) }
				@asker.autofollow_count(8).must_equal 0
			end

			it "follows proper number of users per day and week" do
				@asker.follows.count.must_equal 0
				Timecop.travel(Time.now.beginning_of_week)
				twi_user_ids = (1..38).to_a
				7.times do
					24.times do
						@asker.autofollow(twi_user_ids: twi_user_ids, force: true)
						Timecop.travel(Time.now + 1.hour)
					end
				end
				@asker.follows.count.must_equal 38
			end

			it "doesn't include followbacks in max follows per day" do
				@asker.follows.count.must_equal 0
				twi_user_ids = (5..10).to_a
				@asker.followback(@asker.followers.collect(&:twi_user_id))
				@asker.reload.follows.count.must_equal 1
				@asker.send_autofollows(twi_user_ids, 5, true)
				@asker.reload.follows.count.must_equal 6
			end
		end

		describe "updates followers" do
			it "adds new follower" do
				@asker.followers.count.must_equal 1
		    twi_follower_ids = [@user.twi_user_id, @new_user.twi_user_id]
		    wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
		    @asker.update_followers(twi_follower_ids, wisr_follower_ids)
		    @asker.reload.followers.count.must_equal 2
			end

			it "follows new follower back" do
				@asker.follows.must_be_empty
		    twi_follower_ids = [@new_user.twi_user_id]
		    wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
		    twi_follower_ids = @asker.update_followers(twi_follower_ids, wisr_follower_ids)
		    @asker.followback(twi_follower_ids)
		    @asker.reload.follows.must_include @new_user
			end

			it "sets correct type_id for user followback" do		
				@asker.follows.must_be_empty
		    twi_follower_ids = [@user.twi_user_id]
		    wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
		    twi_follower_ids = @asker.update_followers(twi_follower_ids, wisr_follower_ids)
		    @asker.followback(twi_follower_ids)
		    @asker.reload.relationships.where("followed_id = ?", @user.id).first.type_id.must_equal 1
			end

			it 'follows new follower back with pending requests' do
				@pending_user = FactoryGirl.create(:user, twi_user_id: 3)
				relationship = @asker.relationships.find_or_create_by_followed_id(@pending_user.id)
				relationship.update_attribute :pending, true

		    twi_follower_ids = [@pending_user.twi_user_id, @new_user.twi_user_id]
		    wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
		    twi_follower_ids = @asker.update_followers(twi_follower_ids, wisr_follower_ids)

		    @asker.followback(twi_follower_ids)
		    @asker.reload.follows.must_include @new_user				
			end

			it 'updates converted pending users to not pending' do
				@pending_user = FactoryGirl.create(:user, twi_user_id: 3)
				relationship = @asker.relationships.find_or_create_by_followed_id(@pending_user.id)
				relationship.update_attribute :pending, true

		    relationship.reload.pending.must_equal true
		    relationship.reload.active.must_equal true

		    twi_follows_ids = [@pending_user.twi_user_id]
		    wisr_follows_ids = @asker.followers.collect(&:twi_user_id)
		    @asker.update_follows(twi_follows_ids, wisr_follows_ids)

		    relationship.reload.pending.must_equal false
		    relationship.reload.active.must_equal true
			end

			it "removes unfollowers" do
		    twi_follower_ids = []
		    wisr_follower_ids = @asker.followers.collect(&:twi_user_id)		    
		    @asker.update_followers(twi_follower_ids, wisr_follower_ids)
		    @asker = @asker.reload
		    @asker.followers.count.must_equal 0
		    @asker.reverse_relationships.count.must_equal 1
			end
		end

		describe "updates follows" do
			it "adds new follows" do
				@asker.follows.count.must_equal 0
		    twi_follows_ids = [@user.twi_user_id, @new_user.twi_user_id]
		    wisr_follows_ids = @asker.follows.collect(&:twi_user_id)
		    @asker.update_follows(twi_follows_ids, wisr_follows_ids)
		    @asker.reload.follows.count.must_equal 2				
			end

			it "removes unfollows" do
				@asker.follows << @new_user
		    twi_follows_ids = []
		    wisr_follows_ids = @asker.follows.collect(&:twi_user_id)		    
		    @asker.update_follows(twi_follows_ids, wisr_follows_ids)
		    @asker = @asker.reload
		    @asker.follows.count.must_equal 0
		    @asker.relationships.count.must_equal 1
			end

			it "sets correct type_id for asker followback" do
		    twi_follows_ids = [@user.twi_user_id, @new_user.twi_user_id]
		    wisr_follows_ids = @asker.follows.collect(&:twi_user_id)
		    @asker.update_follows(twi_follows_ids, wisr_follows_ids)
		    @asker = @asker.reload
		    @asker.relationships.where("followed_id = ?", @new_user.id).first.type_id.must_be_nil
			end

			it "unfollows non-reciprocal follows after one month" do
				@asker.follows << @new_user
				twi_follows_ids = [@new_user.twi_user_id]
				32.times do |i|
					Timecop.travel(Time.now + 1.day)
					@asker.unfollow_nonreciprocal(twi_follows_ids)
					if i < 30
						@asker.reload.follows.count.must_equal 1
					else
						@asker.reload.follows.count.must_equal 0
					end
				end
			end

			it "unfollows non-reciprocal pending follows after one month" do
				@asker.follows.must_be_empty
				relationship = @asker.relationships.find_or_create_by_followed_id(@new_user.id)
				relationship.update_attribute :pending, true

				twi_follows_ids = [@new_user.twi_user_id]
				32.times do |i|
					Timecop.travel(Time.now + 1.day)
					@asker.unfollow_nonreciprocal(twi_follows_ids)
					if i < 30
						@asker.reload.follows.count.must_equal 1
					else
						@asker.reload.follows.count.must_equal 0
					end
				end
			end

			it "does not unfollow reciprocal follow after one month" do
				@asker.follows << @new_user
				@new_user.follows << @asker
				twi_follows_ids = [@new_user.twi_user_id]
				32.times do |i|
					Timecop.travel(Time.now + 1.day)
					@asker.unfollow_nonreciprocal(twi_follows_ids)
					@asker.reload.follows.count.must_equal 1
				end
			end

			it "doesn't followback inactive unfollows" do
				@inactive_user1 = FactoryGirl.create(:user, twi_user_id: 3)
				@asker.follows << @inactive_user1
				@asker.unfollow_oldest_inactive_user
				@asker.follows.count.must_equal 1

				Timecop.travel(Time.now + 3.months)
				@asker.reload.unfollow_oldest_inactive_user
				@asker.reload.followback [@inactive_user1.twi_user_id]
				@asker.reload.follows.count.must_equal 0
			end

			it "sets unfollows to inactive" do
				@asker.follows << @new_user
				@asker.relationships.active.count.must_equal 1
				twi_follows_ids = [@new_user.twi_user_id]
				Timecop.travel(Time.now + 32.days)
				rel_count = @asker.reload.relationships.count
				@asker.unfollow_nonreciprocal(twi_follows_ids)
				@asker.reload.relationships.active.count.must_equal 0
				@asker.reload.relationships.count.must_equal rel_count
			end
 		end		
	end

	describe "requests after answer" do

		describe 'ugc' do
			it 'with a post' do
				30.times do |i|
					@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
				end
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 1
			end

			it 'unless already sent' do
				30.times do |i|
					@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
					Timecop.travel(Time.now + 1.day)
				end
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 1
			end

			it 'unless less than 10' do
				8.times do |i|
					@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
					@asker.request_ugc @user
					Timecop.travel(Time.now + 1.day)
				end
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 0
			end

			it 'if greater than 10' do
				10.times do |i|
					@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
					@asker.request_ugc @user
				end
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 1
			end

			it 'unless already written question' do
				@question = FactoryGirl.create(:question, user_id: @user.id, status: 1)		
				10.times do |i|
					@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
					@asker.request_ugc @user
				end
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 0
			end
		end

		describe 'mod' do
			it 'with a post' do
				@user.update_attribute :lifecycle_segment, 4
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
				@asker.request_mod @user.reload
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 1
			end

			it 'with two posts in 5 days' do
				@user.update_attribute :lifecycle_segment, 4
				7.times do |i|
					if i == 0 
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
					elsif i < 6
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 1
					else
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 2
					end

					@asker.request_mod @user.reload
					Timecop.travel(Time.now + 1.day)
				end
			end

			it 'unless lifecycle less than advanced' do
				SEGMENT_HIERARCHY[1].each do |lifecycle_segment|
					user = FactoryGirl.create(:user, twi_user_id: 1)
					@asker.followers << user
					user.update_attribute :lifecycle_segment, lifecycle_segment
					
					@asker.posts.where(in_reply_to_user_id: user.id).where(intention: 'request mod').count.must_equal 0
					@asker.request_mod user.reload

					if SEGMENT_HIERARCHY[1].slice(0,4).include? lifecycle_segment
						@asker.posts.where(in_reply_to_user_id: user.id).where(intention: 'request mod').count.must_equal 0
					else
						@asker.posts.where(in_reply_to_user_id: user.id).where(intention: 'request mod').count.must_equal 1
					end
				end
			end

			it 'uses correct script' do
				@user.update_attribute :lifecycle_segment, 4
				7.times do |i|
					if i == 0 
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
					elsif i < 6
						request_mod = @asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').order('created_at DESC').first
						user_mod_post = FactoryGirl.create(:post, in_reply_to_user_id: @asker.id, moderator_id: @user.id)
						request_mod.text.include?("more").must_equal false
					else
						request_mod = @asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').order('created_at DESC').first
						request_mod.text.include?("more").must_equal true
					end
					@asker.request_mod @user.reload
					Timecop.travel(Time.now + 1.day)
				end
			end
				
			it 'sets role to moderator' do
				@user.update_attribute :lifecycle_segment, 4
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
				@asker.request_mod @user.reload
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 1
				@user.is_role?('moderator').must_equal true
			end

			describe 'through age progression' do
				it 'with no mods' do
					Timecop.travel(Time.now.beginning_of_week)
					5.times do
						@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
					end
					30.times do |i|
						@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
						Timecop.travel(Time.now + 1.day)
					end
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 2
				end

				it 'with regular mods' do
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
					@user.update_attribute :lifecycle_segment, 4
					30.times do |i|
						user_response = FactoryGirl.create(:post, in_reply_to_user_id: @asker.id, moderator_id: @user.id)
						@asker.request_mod @user.reload
						Timecop.travel(Time.now + 1.day)
					end
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 6
				end
			end

			it 'unless just transitioned' do
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
				@user.update_attribute :lifecycle_segment, nil
				@asker.app_response FactoryGirl.create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
				@asker.request_mod @user
				@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
			end
		end

		# describe 'nudge'  do
		# 	it 'with a post'
		# 	it 'unless already nudged'
		# 	it 'unless no client'
		# 	it 'unless no active/automatic nudge_type'
		# 	it 'unless fewer than 3 answers'
		# 	it 'unless does not follow asker'
		# end
	end
end