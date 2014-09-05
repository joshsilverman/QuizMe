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
			@conversation = create(:conversation,
				post: @question_status,
				publication: @publication)

			@conversation.posts << @user_response = create(:post,
				text: 'the correct answer, yo',
				user_id: @user.id,
				in_reply_to_user_id: @asker.id,
				interaction_type: 2,
				in_reply_to_question_id: @question.id)

			@correct = [1, 2].sample == 1

			@incorrect_answer = create(:answer,
				correct: false,
				text: 'the incorrect answer',
				question_id: @question.id)
		end


		it "with a post" do
			@asker.app_response @user_response, @correct
			@asker.posts
				.where("intention = 'grade' and in_reply_to_user_id = ?", @user.id)
				.wont_be_empty
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

describe Asker, ".mention_new_users" do
  it "with intention new user question mention" do
    asker = create(:asker)
    publication = create(:publication,
      asker_id: asker.id,
      question: create(:question))
    asker_post = create(:post,
      user: asker,
      publication: publication)

    user = create(:user, learner_level: 'dm answer')
    user_post = create(:post,
      in_reply_to_user_id: asker.id,
      user_id: user.id)

    Asker.mention_new_users

    Post.where(intention: 'new user question mention').count
      .must_equal 1
  end

  it "with correct link" do
    asker = create(:asker)
    publication = create(:publication,
      asker_id: asker.id,
      question: create(:question))
    asker_post = create(:post,
      user: asker,
      publication: publication)

    user = create(:user, learner_level: 'dm answer')
    user_post = create(:post,
      in_reply_to_user_id: asker.id,
      user_id: user.id)

    Asker.mention_new_users

    next_question = Post.where(intention: 'new user question mention').first
    uri = URI.parse(next_question.url)

    uri.path.must_equal "/#{asker.subject_url}/#{publication.id}"
  end
end

describe Asker, "#notify_badge_issued" do
  it 'must call send_private_message with user and message with link' do
    asker = Asker.new
    badge = Badge.new(title:'badger', description:'Excellence in badgering')
    issuance = Issuance.create
    url = URL + issuance_path(issuance)

    user = create :user
    message = "@#{user.twi_screen_name} You earned the #{badge.title} badge, congratulations!"
    options = {long_url: url, in_reply_to_user_id: user.id}

    asker.expects(:send_public_message).with(message, options)

    asker.notify_badge_issued(user, badge, options)
  end
end

describe Asker, "#auto_respond" do
  it "method exists" do
    asker = Asker.new

    asker.methods.must_include :auto_respond
  end
end

describe Asker, "#subject_url" do
  it "downcases subject" do
    asker = Asker.new subject: "Biology"

    asker.subject_url.must_equal 'biology'
  end

  it "handles nil subject" do
    asker = Asker.new subject: nil

    asker.subject_url.must_equal ''
  end

  it "replaces spaces with dashes" do
    asker = Asker.new subject: "Harry Potter"

    asker.subject_url.must_equal 'harry-potter'
  end
end

describe Asker, ".find_by_subject_url" do
  it "finds regardless of subject case" do
    asker = Asker.create subject: "Biology"

    found_asker = Asker.find_by_subject_url 'biology'

    found_asker.must_equal asker
  end

  it "find multiword subjects" do
    asker = Asker.create subject: "Harry Potter"

    found_asker = Asker.find_by_subject_url 'harry-potter'

    found_asker.must_equal asker
  end
end

describe Asker, '#publish_question' do
  it 'sets first posted at time' do
    asker = create :asker, posts_per_day: 5
    publication = create :publication, first_posted_at: nil
    queue = PublicationQueue.create asker: asker
    queue.publications.push publication

    Timecop.freeze
    time = Time.now

    asker.publish_question

    publication.reload.first_posted_at.to_i.must_equal time.to_i
  end

  it 'wont update first posted at if already set' do
    asker = create :asker, posts_per_day: 5
    publication = create :publication, first_posted_at: nil
    queue = PublicationQueue.create asker: asker
    queue.publications.push publication

    Timecop.freeze
    time = Time.now

    asker.publish_question

    queue.reload.update index: 0
    Timecop.travel 1.hours
    asker.reload.publish_question

    publication.reload.first_posted_at.to_i.must_equal time.to_i
  end
end
