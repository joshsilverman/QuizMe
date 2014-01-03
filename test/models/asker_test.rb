require 'test_helper'

describe Asker do
	before :each do 
		@asker = create(:asker)
		@user = create(:user, twi_user_id: 1)

		@asker.followers << @user		

		@question = create(:question, created_for_asker_id: @asker.id, status: 1)		
		@publication = create(:publication, question_id: @question.id)
		@question_status = create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)		
		Delayed::Worker.delay_jobs = false
	end

	describe "responds to user answer" do
		before :each do 
			@conversation = create(:conversation, post: @question_status, publication: @publication)
			@conversation.posts << @user_response = create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)


			@correct = [1, 2].sample == 1
			@incorrect_answer = create(:answer, correct: false, text: 'the incorrect answer', question_id: @question.id)
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
			app_response.text.include?(@question.answers.correct.text).must_equal true
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

		describe 'from autoresponse' do
			it 'automatically responds to autocorrected posts' do
				@user_response.update_attributes(requires_action: true, autocorrect: true)
				@asker.auto_respond(@user_response)
				@user_response.reload.requires_action.must_equal false
				@asker.posts.where(intention: 'grade', in_reply_to_post_id: @user_response.id).count.must_equal 1
			end

			it 'won\'t response to un-autocorrected posts' do
				@user_response.update_attributes(requires_action: true, autocorrect: nil)
				@asker.auto_respond(@user_response)
				@user_response.reload.requires_action.must_equal true
				@asker.posts.where(intention: 'grade', in_reply_to_post_id: @user_response.id).count.must_equal 0
			end
		end
	end

	describe "reengages users" do
		describe "that have" do
			it "answered a question" do
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(:user_id => @asker.id, 
					:in_reply_to_user_id => @user.id).must_be_empty
				
				create(:post, text: 'the correct answer, yo', 
					user: @user, 
					in_reply_to_user_id: @asker.id, 
					interaction_type: 2, 
					in_reply_to_question_id: @question.id, 
					correct: true)

				Timecop.travel(Time.now + 1.day)

				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(:user_id => @asker.id, 
					:in_reply_to_user_id => @user.id).wont_be_empty
			end	

			it "moderated a post" do
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(user_id: @asker.id, in_reply_to_user_id: @user.id).must_be_empty

				create(:post_moderation, user_id: @user.id, type_id: 1, post: create(:post))
				Timecop.travel(Time.now + 1.day)

				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(user_id: @asker.id, in_reply_to_user_id: @user.id).wont_be_empty				
			end

			it "written a question" do
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(user_id: @asker.id, in_reply_to_user_id: @user.id).must_be_empty

				create(:question, user_id: @user.id, created_for_asker_id: @asker.id)
				Timecop.travel(Time.now + 1.day)

				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(user_id: @asker.id, in_reply_to_user_id: @user.id).wont_be_empty
			end

			it "gone inactive" do
				create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true)
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).must_be_empty

				Timecop.travel(Time.now + 1.day)
				create(:post_moderation, user_id: @user.id, type_id: 1, post: create(:post))
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).must_be_empty				

				Timecop.travel(Time.now + 1.day)
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).wont_be_empty				
			end	
		end

		describe "who are qualified" do
			before :each do
				@strategy = [1, 2, 4, 8]

				@user_response = create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)
				@user_response.update_attribute :correct, true
				@user.update_attributes last_answer_at: @user_response.created_at, last_interaction_at: @user_response.created_at, activity_segment: nil

				create(:post, in_reply_to_user_id: @asker.id, correct: true, interaction_type: 2, in_reply_to_question_id: @question.id)
			end

			it "with a post" do
				Timecop.travel(Time.now + 1.day)
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).wont_be_empty
			end

			it "on the proper schedule" do 
				intervals = []
				@strategy.each_with_index { |e, i| intervals << @strategy[0..i].sum }
				(@strategy.sum + 1).times do |i|
					Asker.reengage_inactive_users strategy: @strategy
					Post.reengage_inactive.where("user_id = ? and in_reply_to_user_id = ? and created_at > ?", @asker.id, @user.id, Time.now.beginning_of_day).present? if intervals.include? i
					Timecop.travel(Time.now + 1.day)
				end
			end	

			it "from an asker that they are following" do
				Timecop.travel(Time.now + 1.day)
				@asker.followers.delete @user
				Asker.reengage_inactive_users strategy: @strategy
				Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).must_be_empty
			end

			it "unless they've already been reengaged" do
				Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).count.must_equal 0
				Timecop.travel(Time.now + 1.day)
				2.times do 
					Asker.reengage_inactive_users strategy: @strategy
					Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).count.must_equal 1
				end
			end

      it 'with a question' do
        Timecop.travel(Time.now + 1.day)
        Asker.reengage_inactive_users strategy: @strategy, type: :question
        posts = Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)
        posts.count.must_equal 1
        post = posts.first
        post.question_id.wont_be_nil and post.intention.must_equal 'reengage inactive'
      end

      it 'with a moderation request' do
        Timecop.travel(Time.now + 1.day)
        Asker.reengage_inactive_users strategy: @strategy, type: :moderation
        posts = Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)
        posts.count.must_equal 1
        post = posts.first
        post.question_id.must_be_nil and post.intention.must_equal 'request mod'
      end

      it 'with an author request' do
        Timecop.travel(Time.now + 1.day)
        Asker.reengage_inactive_users strategy: @strategy, type: :author
        posts = Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)
        posts.count.must_equal 1
        post = posts.first
        post.question_id.must_be_nil and post.intention.must_equal 'solicit ugc'
      end

			describe "with a question" do
				it "that has been approved" do
					Timecop.travel(Time.now + 1.day)
					@unapproved_question = create(:question, created_for_asker_id: @asker.id, status: 0)
					Asker.reengage_inactive_users strategy: @strategy
					Post.reengage_inactive
						.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)
						.first.question.status.must_equal 1
				end
			end				
		end
	end

	describe 'sends targeted mentions' do
		before :each do 
			Delayed::Worker.delay_jobs = true
			Timecop.travel(Time.now.beginning_of_week + 1.minute)
			300.times { @asker.followers << create(:user) }
		end

		it 'sends targeted mentions 5 days a week' do 
			mention_counts = []
			@asker.stub :followers, 1..10000 do
				14.times do 
					mention_counts << @asker.targeted_mention_count
					Timecop.travel(Time.now + 1.day)
				end
			end
			mention_counts.count(0).must_equal 4
		end

		it 'sends the proper number of mentions per day' do
			mention_count = @asker.targeted_mention_count
			while (mention_count < 1) do 
				Timecop.travel(Time.now + 1.day)
				mention_count = @asker.targeted_mention_count
			end
			@asker.posts.where("intention = ?", 'targeted mention').count.must_equal 0

			target_users = []
			10.times { target_users << create(:user) }
			@asker.schedule_targeted_mentions({ target_users: target_users })
			24.times do
				Timecop.travel(Time.now + 1.hour)
				Delayed::Worker.new.work_off
			end

			@asker.reload.posts.where("intention = ?", 'targeted mention').count.must_equal mention_count
		end

		it 'on proper schedule' do 
			mention_count = @asker.targeted_mention_count
			while (mention_count < 1) do 
				Timecop.travel(Time.now + 1.day)
				mention_count = @asker.targeted_mention_count
			end
			target_users = []
			10.times { target_users << create(:user) }
			@asker.schedule_targeted_mentions({ target_users: target_users })
			interval = (24 / mention_count.to_f)
			count = 0
			24.times do |i|
				Delayed::Worker.new.work_off
				count += 1 if (i % interval == 0)
				@asker.posts.where("intention = ?", 'targeted mention').count.must_equal count
				Timecop.travel(Time.now + 1.hour)
			end			
		end

		it "doesn't exceed daily max if jobs are mistakenly scheduled" do
			mention_count = @asker.targeted_mention_count

			# advance to day of week where mentions sent
			while (mention_count < 1) do 
				Timecop.travel(Time.now + 1.day)
				mention_count = @asker.targeted_mention_count
			end

			mention_count.times do 
				create(:post, intention: 'targeted mention', user: @asker) 
			end

      Delayed::Job.enqueue(
        TargetedMention.new(@asker, create(:user)),
        :run_at => Time.now
      )  
      Delayed::Worker.new.work_off
      @asker.posts.where("intention = ?", 'targeted mention').count
      	.must_equal mention_count
		end
	end

	describe 'requests' do
		describe 'after answer' do
			describe 'unless' do
				before :each do 
					# qualify user for all solicitations
					50.times { @question = create(:question, created_for_asker_id: @asker.id, status: 1) }
					@new_asker = create(:asker, published: nil)
					@new_asker.related_askers << @asker
					15.times { create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
					@user.update_attribute :lifecycle_segment, 4
					Timecop.travel(Time.now + 2.hours)

					@answerer = create(:user)
					@question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)		
					@publication = create(:publication, question: @question, asker: @asker)
					@post_question = create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)		
					@conversation = create(:conversation, post: @post_question, publication: @publication)
					@post = create :post, 
						user: @answerer, 
						requires_action: true, 
						in_reply_to_post_id: @post_question.id,
						in_reply_to_user_id: @asker.id,
						in_reply_to_question_id: @question.id,
						interaction_type: 2, 
						conversation: @conversation				
				end
				
				it 'already requested in the past four hours' do
					@asker.after_answer_action @user
					Post.where("in_reply_to_user_id = ? and (intention like ? or intention like ?)", @user.id, '%request%', '%solicit%').count.must_equal 1
					Timecop.travel(Time.now + 5.minutes)
					4.times do |i|
						Timecop.travel(Time.now + 1.hour)
						@asker.after_answer_action @user
						if i == 2
							Post.where("in_reply_to_user_id = ? and (intention like ? or intention like ?)", @user.id, '%request%', '%solicit%').count.must_equal 1
						elsif i == 4
							Post.where("in_reply_to_user_id = ? and (intention like ? or intention like ?)", @user.id, '%request%', '%solicit%').count.must_equal 2
						end
					end
				end

				it 'more than one unresponded request in past week' do
					14.times do |i|
						@asker.after_answer_action @user
						Timecop.travel(Time.now + 1.day)
						if i == 0
							Post.where("in_reply_to_user_id = ? and (intention like ? or intention like ?)", @user.id, '%request%', '%solicit%').count.must_equal 1
						elsif i == 1
							Post.where("in_reply_to_user_id = ? and (intention like ? or intention like ?)", @user.id, '%request%', '%solicit%').count.must_equal 2
						elsif i == 7
							Post.where("in_reply_to_user_id = ? and (intention like ? or intention like ?)", @user.id, '%request%', '%solicit%').count.must_equal 3
						elsif i == 14
							[4,5].must_include Post.where("in_reply_to_user_id = ? and (intention like ? or intention like ?)", @user.id, '%request%', '%solicit%').count
						end
					end
				end
			end

			describe 'ugc' do
				it 'with a post' do
					Timecop.travel(Time.now + 7.days)
					12.times do |i|
						Timecop.travel(Time.now + 1.day)
						@asker.app_response create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
					end
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 1
				end

				it 'unless user has less than 10 answers' do
					8.times do |i|
						create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true)
						@asker.request_new_question @user
						Timecop.travel(Time.now + 1.day)
					end
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 0
				end

				it 'if user has greater than 10 answers' do
					10.times do |i|
						@asker.app_response create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
						@asker.request_new_question @user
					end
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 1
				end

				it 'with two posts in fifteen days' do
					15.times { create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
					16.times do |i|
						if i == 0 
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 0
						elsif i < 15
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 1
						else
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 2
						end

						@asker.request_new_question @user.reload
						Timecop.travel(Time.now + 1.day)
					end
				end

				it 'uses correct script' do
					11.times { create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
					4.times do |i|
						question = nil
						new_question_post = @asker.reload.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').order('created_at DESC').first
						case i
						when 0
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 0
						when 1
							new_question_post.text.include?("more").must_equal false						
							question = create(:question, created_for_asker_id: @asker.id, user_id: @user.id, status: 0)
						when 2
							new_question_post.text.include?("more").must_equal true
							question = create(:question, created_for_asker_id: @asker.id, user_id: @user.id, status: 0)
						else						
							new_question_post.text.include?("more").must_equal true
							new_question_post.text.include?("last week").must_equal true
							question = create(:question, created_for_asker_id: @asker.id, user_id: @user.id, status: 0)
						end

						@asker.request_new_question @user.reload
						Timecop.travel(Time.now + 15.days)
						10.times { create(:post, text: 'the correct answer, yo', user_id: create(:user).id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: question.id, correct: true) } if question
					end
				end			

				describe 'through age progression' do
					it 'with no contributions' do
						Timecop.travel(Time.now.beginning_of_week)
						15.times { create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
						6.times do
							@asker.app_response create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
							Timecop.travel(Time.now + 7.day)
						end
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 2
					end

					it 'with regular contributions' do
						15.times { create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 0
						10.times do
							create(:question, created_for_asker_id: @asker.id, user_id: @user.id, status: 0)		
							@asker.request_new_question @user.reload
							Timecop.travel(Time.now + 5.days)
						end
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'solicit ugc').count.must_equal 4
					end
				end		
			end

			describe 'mod' do
				before :each do 
					@answerer = create(:user)
					@question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)		
					@publication = create(:publication, question: @question, asker: @asker)
					@post_question = create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)		
					@conversation = create(:conversation, post: @post_question, publication: @publication)
					@post = create :post, 
						user: @answerer, 
						requires_action: true, 
						in_reply_to_post_id: @post_question.id,
						in_reply_to_user_id: @asker.id,
						in_reply_to_question_id: @question.id,
						interaction_type: 2, 
						conversation: @conversation
				end

				it 'with a post' do
					@user.update_attribute :lifecycle_segment, 3
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
					@asker.request_mod @user.reload
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 1
				end

				it 'with two posts in 5 days' do
					@user.update_attribute :lifecycle_segment, 3
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

				it 'unless lifecycle less than regular' do
					SEGMENT_HIERARCHY[1].each do |lifecycle_segment|
						user = create(:user, twi_user_id: 1)
						@asker.followers << user
						user.update_attribute :lifecycle_segment, lifecycle_segment
						
						@asker.posts.where(in_reply_to_user_id: user.id).where(intention: 'request mod').count.must_equal 0
						@asker.request_mod user.reload

						if SEGMENT_HIERARCHY[1].slice(0,3).include? lifecycle_segment
							@asker.posts.where(in_reply_to_user_id: user.id).where(intention: 'request mod').count.must_equal 0
						else
							@asker.posts.where(in_reply_to_user_id: user.id).where(intention: 'request mod').count.must_equal 1
						end
					end
				end

				it 'unless no posts to moderate' do
					@user.update_attribute :lifecycle_segment, 3
					@post.destroy
					@asker.request_mod @user.reload
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
				end

				it 'uses correct script' do
					@user.update_attribute :lifecycle_segment, 3
					7.times do |i|
						if i == 0 
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
						elsif i < 6
							request_mod = @asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').order('created_at DESC').first
							create(:post_moderation, user_id: @user.id, type_id: 1, post: create(:post))
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
					@user.update_attribute :lifecycle_segment, 3
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
					@asker.request_mod @user.reload
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 1
					@user.is_role?('moderator').must_equal true
				end

				describe 'through age progression' do
					it 'with no mods' do
						Timecop.travel(Time.now.beginning_of_week)
						5.times do
							@asker.app_response create(:post, 
												in_reply_to_question_id: @question.id, 
												in_reply_to_user_id: @asker.id, 
												user_id: @user.id
											), true
							@user.segment
						end
						6.times do |i|
							@asker.app_response create(:post, 
												in_reply_to_question_id: @question.id, 
												in_reply_to_user_id: @asker.id, 
												user_id: @user.id
											), true
							@user.segment
							Timecop.travel(Time.now + 5.day)
						end

						@asker.posts.where(in_reply_to_user_id: @user.id).
										where(intention: 'request mod').count.must_equal 2
					end

					it 'with regular mods' do
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
						@user.update_attribute :lifecycle_segment, 3
						30.times do |i|
							create(:post_moderation, user_id: @user.id, type_id: 1, post: create(:post))
							@asker.request_mod @user.reload
							Timecop.travel(Time.now + 1.day)
						end
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 6
					end
				end

				it 'unless just transitioned' do
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
					@user.update_attribute :lifecycle_segment, nil
					@asker.app_response create(:post, in_reply_to_question_id: @question.id, in_reply_to_user_id: @asker.id, user_id: @user.id), true
					@asker.request_mod @user
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request mod').count.must_equal 0
				end
			end

			describe 'new handle ugc' do
				before :each do 
					50.times do 
						@question = create(:question, created_for_asker_id: @asker.id, status: 1)		
					end

					@new_asker = create(:asker, published: nil)
					@new_asker.related_askers << @asker
				end

				it 'with a post' do
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 0
					15.times { create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
					@user.update_attribute :lifecycle_segment, 3
					@asker.request_new_handle_ugc @user
					@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 1
				end

				it 'unless lifecycle less than regular' do
					SEGMENT_HIERARCHY[1].each do |lifecycle_segment|
						user = create(:user, twi_user_id: 1)
						15.times { create(:post, text: 'the correct answer, yo', user_id: user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
						user.update_attribute :lifecycle_segment, lifecycle_segment
						
						@asker.posts.where(in_reply_to_user_id: user.id).where(intention: 'request new handle ugc').count.must_equal 0
						@asker.request_new_handle_ugc user.reload

						if SEGMENT_HIERARCHY[1].slice(0, 3).include? lifecycle_segment
							@asker.posts.where(in_reply_to_user_id: user.id).where(intention: 'request new handle ugc').count.must_equal 0
						else
							@asker.posts.where(in_reply_to_user_id: user.id).where(intention: 'request new handle ugc').count.must_equal 1
						end
					end
				end			

				it 'if enough answers on related handle' do
					@user.update_attribute :lifecycle_segment, 3
					12.times do |i|
						if i > 10
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 1
						else
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 0
						end

						create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true)
						@user.update_attribute :lifecycle_segment, 3
						@asker.request_new_handle_ugc @user
					end
				end

				it 'with two posts in eight days' do
					15.times { create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
					@user.update_attribute :lifecycle_segment, 3
					8.times do |i|
						if i == 0 
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 0
						elsif i < 8
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 1
						else
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 2
						end

						@asker.request_new_handle_ugc @user.reload
						Timecop.travel(Time.now + 1.day)
					end
				end

				it 'uses correct script' do
					15.times { create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
					@user.update_attribute :lifecycle_segment, 3
					7.times do |i|
						new_handle_ugc = @asker.reload.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').order('created_at DESC').first
						case i
						when 0
							@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 0
						when 1
							new_handle_ugc.text.include?("more").must_equal false						
							create(:question, created_for_asker_id: @new_asker.id, user_id: @user.id, status: 0)
						else
							new_handle_ugc.text.include?("more").must_equal true
							create(:question, created_for_asker_id: @new_asker.id, user_id: @user.id, status: 0)
						end

						@asker.request_new_handle_ugc @user.reload
						Timecop.travel(Time.now + 8.days)
					end
				end			

				describe 'through age progression' do
					it 'with no contributions' do
						Timecop.travel(Time.now.beginning_of_week)
						5.times do
							@asker.app_response create(:post, 
												in_reply_to_question_id: @question.id, 
												in_reply_to_user_id: @asker.id, 
												user_id: @user.id
											), true
							@user.segment
						end
						9.times do
							Timecop.travel(Time.now + 7.day)
							@asker.app_response create(:post, 
												in_reply_to_question_id: @question.id, 
												in_reply_to_user_id: @asker.id, 
												user_id: @user.id
											), true
							@user.segment
						end

						@asker.posts.where(in_reply_to_user_id: @user.id).
										where(intention: 'request new handle ugc').
										count.must_equal 2
					end

					it 'with regular contributions' do
						15.times { create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id, correct: true) }
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 0
						@user.update_attribute :lifecycle_segment, 3
						15.times do
							create(:question, created_for_asker_id: @new_asker.id, user_id: @user.id, status: 0)		
							@asker.request_new_handle_ugc @user.reload
							Timecop.travel(Time.now + 3.day)
						end
						@asker.posts.where(in_reply_to_user_id: @user.id).where(intention: 'request new handle ugc').count.must_equal 5
					end
				end		
			end
		end

		describe '#request_feedback_on_question' do
			before :each do 
				@moderator = create(:moderator)
				@author = create(:user)
			end

			it 'with a post' do
				@asker.followers << @moderator
				create(:question_moderation, 
								user_id: @moderator.id, 
								question_id: @question.id)
				create(:question, text: 'Hey man, sup?', 
								user_id: @author.id, 
								created_for_asker_id: @asker.id)

				@question.asker.request_feedback_on_question(@question)

				@asker.posts.where(in_reply_to_user_id: @moderator.id, 
									intention: 'request question feedback').
								count.must_equal(1)
			end

			it 'only when question created' do
				@asker.followers << @moderator
				create(:question_moderation, 
								user_id: @moderator.id, 
								question_id: @question.id)
				@question.update(text: 'updated some text?')

				@asker.posts.where(
									in_reply_to_user_id: @moderator.id, 
									intention: 'request question feedback').
								count.must_equal(0)

				create(:question, text: 'Hey man, sup?', 
								user_id: @author.id, 
								created_for_asker_id: @asker.id)
				@question.asker.request_feedback_on_question(@question)

				@asker.posts.where(in_reply_to_user_id: @moderator.id, 
									intention: 'request question feedback').
								count.must_equal(1)
			end

			it 'from users who are question moderators for that asker' do
				create(:question_moderation, user_id: @moderator.id, question_id: @question.id)
				create(:question, text: 'Hey man, sup?', user_id: @author.id, created_for_asker_id: @asker.id)
				@asker.posts.where(in_reply_to_user_id: @moderator.id, intention: 'request question feedback').count.must_equal(0)
			end

			describe 'unless' do
				before :each do 
					@asker.followers << @moderator
					create(:question_moderation, 
									user_id: @moderator.id, 
									question_id: @question.id)
				end

				it 'moderator wrote the question' do
					question = create(:question, text: 'Hey man, sup?', 
									user_id: @moderator.id, 
									created_for_asker_id: @asker.id)
					question.asker.request_feedback_on_question(question)

					@asker.posts.where(in_reply_to_user_id: @moderator.id, 
										intention: 'request question feedback').
									count.must_equal(0)
				end

				it 'moderator hasnt been active in the past week' do
					Timecop.travel(Time.now + 8.days)
					create(:question, text: 'Hey man, sup?', 
									user_id: @author.id, 
									created_for_asker_id: @asker.id)
					@question.asker.request_feedback_on_question(@question)

					@asker.posts.where(in_reply_to_user_id: @moderator.id, 
										intention: 'request question feedback').
									count.must_equal(0)
				end

				it 'moderator received a feedback request in the past week' do
					create(:question, 
									text: 'Hey man, sup?', 
									user_id: @author.id, 
									created_for_asker_id: @asker.id)
					@question.asker.request_feedback_on_question(@question)

					@asker.posts.where(
										in_reply_to_user_id: @moderator.id, 
										intention: 'request question feedback').
									count.must_equal(1)

					Timecop.travel(Time.now + 5.days)

					create(:question, text: 'Hey bro, sup?', 
									user_id: @author.id, 
									created_for_asker_id: @asker.id)
					@question.asker.request_feedback_on_question(@question)

					@asker.posts.where(in_reply_to_user_id: @moderator.id, intention: 'request question feedback').count.must_equal(1)
				end

				it 'moderator received a request in the past three days' do
					create(:post, text: 'Want to mod??', 
									user_id: @asker.id, 
									in_reply_to_user_id: @moderator.id, 
									interaction_type: 4, 
									intention: 'request mod')

					create(:question, text: 'Hey man, sup?', 
									user_id: @author.id, 
									created_for_asker_id: @asker.id)
					@question.asker.request_feedback_on_question(@question)

					@asker.posts.where(in_reply_to_user_id: @moderator.id, 
										intention: 'request question feedback').
									count.must_equal(0)
				end
			end
		end		
	end

	describe "follows up with incorrect answerers" do
		before :each do 
			@conversation = create(:conversation, publication_id: @publication.id)
			@user_response = create(:post, text: 'the incorrect answer', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)
			@conversation.posts << @user_response

			Delayed::Worker.delay_jobs = true
			Delayed::Worker.new.work_off
		end

		it 'with a post' do
			@asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", @user.id).count.must_equal 0
			@asker.app_response @user_response, false
			16.times do
				Delayed::Worker.new.work_off
				Timecop.travel(Time.now + 1.day)
			end
			@asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", @user.id).count.must_equal 1
		end

		it 'after an interval' do
			@asker.app_response @user_response, false
			Delayed::Worker.new.work_off

			number_of_days_until_followup = (((Delayed::Job.first.run_at - Time.now) / 60 / 60 / 24).to_i + 1)
			number_of_days_until_followup.times do |i|
				Delayed::Worker.new.work_off
				@asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", @user.id).count.must_equal 0
				Timecop.travel(Time.now + 1.day)
			end
			Delayed::Worker.new.work_off
			@asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", @user.id).count.must_equal 1
		end

		it 'unless they answered correctly' do
			@asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", @user.id).count.must_equal 0
			@asker.app_response @user_response, true
			16.times do
				Delayed::Worker.new.work_off
				Timecop.travel(Time.now + 1.day)
			end
			@asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", @user.id).count.must_equal 0
		end

		it 'who have responded to recent followups' do
			@asker.app_response @user_response, false
			Delayed::Worker.new.work_off
			while Delayed::Job.all.size > 0
				Delayed::Worker.new.work_off
				Timecop.travel(Time.now + 1.day)
			end
			followup = @asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", @user.id).first
			new_question = create(:question, created_for_asker_id: @asker.id, status: 1)
			publication = create(:publication, question_id: new_question.id)
			conversation = create(:conversation, publication_id: publication.id)
			user_post = create(:post, text: 'the correct answer', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_post_id: followup.id, in_reply_to_question_id: new_question.id)
			conversation.posts << user_post
			@asker.app_response(user_post, false)
			Delayed::Worker.new.work_off
			Delayed::Job.count.must_equal 1
		end

		it 'unless we already followed up on the question this month' do
			2.times do 
				@asker.app_response @user_response, false
				16.times do |i|
					Delayed::Worker.new.work_off
					Timecop.travel(Time.now + 1.day)
				end
			end
			@asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", @user.id).count.must_equal 1
		end

		it "unless we've already scheduled a followup for the user" do 
			@asker.app_response @user_response, false
			while Delayed::Job.all.size > 0
				new_question = create(:question, created_for_asker_id: @asker.id, status: 1)		
				@asker.app_response create(:post, text: 'the incorrect answer', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: new_question.id), false
				Delayed::Worker.new.work_off
				Timecop.travel(Time.now + 1.day)
			end
			@asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", @user.id).count.must_equal 1
		end 

		it 'unless there is another unresponded to followup from the past week' do
			create(:post, user_id: @asker.id, in_reply_to_user_id: @user.id, intention: 'incorrect answer follow up')
			4.times do |i|
				if i < 3
					Delayed::Job.count.must_equal 0
				else
					Delayed::Job.count.must_equal 1
				end

				new_question = create(:question, created_for_asker_id: @asker.id, status: 1)		
				publication = create(:publication, question_id: new_question.id)
				conversation = create(:conversation, publication_id: publication.id)
				user_post = create(:post, text: 'the incorrect answer', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: new_question.id)
				conversation.posts << user_post
				@asker.app_response(user_post, false)
				Delayed::Worker.new.work_off
				Timecop.travel(Time.now + 4.day)
			end
		end
	end		
end

describe Asker, "#notify_badge_issued" do
  it 'must call send_private_message with user and message with link' do
    asker = Asker.new
    badge = Badge.new(title:'badger', description:'Excellence in badgering')
    issuance = Issuance.create
    url = URL + issuance_path(issuance)

    user = create :user
    message = "@{user.twi_screen_name} You earned the #{badge.title} badge, congratulations! #{url}"
    options = {long_url: url}

    asker.expects(:send_public_message).with(user, message, options)

    asker.notify_badge_issued(user, badge, options)
  end
end