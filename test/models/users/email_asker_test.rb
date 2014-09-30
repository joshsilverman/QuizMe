require 'test_helper'

describe EmailAsker do
  let(:course) {create(:course, :with_lessons)}
  let(:lessons) {course.lessons.sort}
  let(:asker) do
    asker = course.askers.first.becomes(EmailAsker)
    asker.followers << emailer
    asker
  end
  let(:emailer) { create(:emailer, twi_user_id: 1) }
  let(:non_emailer) { create(:user) }
  let(:strategy) { [1, 2, 4, 8] }
  let(:question) { create(:question, created_for_asker_id: asker.id, status: 1) }
  let(:publication) { create(:publication, question_id: question.id) }

  let(:another_question) { create(:question, created_for_asker_id: asker.id, status: 1) }
  let(:another_publication) { create(:publication, question_id: another_question.id) }

  before :each do
    @question_status = create(:post, user_id: asker.id, interaction_type: 1, question_id: question.id, publication_id: publication.id)

    @emailer_response = create(:post, text: 'the correct answer, yo', user_id: emailer.id, in_reply_to_user_id: asker.id, interaction_type: 5, in_reply_to_question_id: question.id)
    @emailer_response.update_attributes created_at: (strategy.first + 1).days.ago, correct: true
    emailer.update_attributes last_answer_at: @emailer_response.created_at, last_interaction_at: @emailer_response.created_at, activity_segment: nil
    create(:post, in_reply_to_user_id: asker.id, correct: true, interaction_type: 2, in_reply_to_question_id: question.id)

    Delayed::Worker.delay_jobs = false
    Asker.reengage_inactive_users strategy: strategy
  end

  it 'is not the default communication preference' do
    User.create.communication_preference.must_equal 1
  end

  describe 'public send' do
    it 'degrades to private send' do
      asker.posts.reengage_inactive.where(in_reply_to_user_id: emailer).first.interaction_type.must_equal 5
    end
  end

  describe 'private send' do
    it 'is used when communication preference is set for email' do
      emailer.communication_preference.must_equal 2
      asker.posts.reengage_inactive.where(in_reply_to_user_id: emailer.reload).first.interaction_type.must_equal 5
    end

    it 'is not used when communication preference is set for Twitter' do
      another_publication

      emailer.update communication_preference: 1
      Timecop.travel 4.days
      Asker.reengage_inactive_users strategy: strategy
      posts = asker.posts.reengage_inactive.where(in_reply_to_user_id: emailer).sort
      posts.count.must_equal 2
      posts.last.interaction_type.wont_equal 5
      ActionMailer::Base.deliveries.count.must_equal 1
    end

    it 'will cause email delivery' do
      ActionMailer::Base.deliveries.wont_be_empty
    end
  end

  describe 'follows up on correct answer' do
    before :each do
      @question_email = create(:email, user_id: asker.id, question_id: question.id, publication_id: publication.id, in_reply_to_user_id: emailer.id)
      @conversation = create(:conversation, post: @question_email, publication: publication)
      Delayed::Worker.delay_jobs = true
    end

    it 'only on correct answers' do
      @conversation.posts << response = create(:email, in_reply_to_question_id: question.id, in_reply_to_post_id: @question_email.id, autocorrect: false, requires_action: true)
      asker.auto_respond(response, emailer)
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
      Timecop.travel(Time.now + 1.day)
      Delayed::Worker.new.work_off
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
    end

    it 'one day later' do
      @conversation.posts << response = create(:email, in_reply_to_question_id: question.id, in_reply_to_post_id: @question_email.id, autocorrect: true, requires_action: true)
      asker.auto_respond(response, emailer)
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
      Timecop.travel(Time.now + 1.day)
      Delayed::Worker.new.work_off
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 1
    end

    it 'only if email version' do
      @conversation = FactoryGirl.create(:conversation, publication_id: publication.id)
      @user_response = FactoryGirl.create(:post, text: 'the incorrect answer', user_id: emailer.id, in_reply_to_user_id: asker.id, interaction_type: 2, in_reply_to_question_id: question.id, in_reply_to_post_id: @question_status.id)
      @conversation.posts << @user_response

      asker.posts.where("intention = 'correct answer follow up' and in_reply_to_user_id = ?", emailer.id).count.must_equal 0
      asker.app_response @user_response, true
      16.times do
        Delayed::Worker.new.work_off
        Timecop.travel(Time.now + 1.day)
      end
      asker.posts.where("intention = 'correct answer follow up' and in_reply_to_user_id = ?", emailer.id).count.must_equal 0
    end

    it 'unless is a followup' do
      @conversation.posts << response = create(:email, in_reply_to_question_id: question.id, in_reply_to_post_id: @question_email.id, autocorrect: true, requires_action: true)
      asker.auto_respond(response, emailer)
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
      Timecop.travel(Time.now + 1.day)
      Delayed::Worker.new.work_off
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 1

      followup = asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').first
      @conversation.posts << response = create(:email, in_reply_to_question_id: question.id, in_reply_to_post_id: followup.id, autocorrect: true, requires_action: true)
      asker.auto_respond(response, emailer)
      Timecop.travel(Time.now + 1.day)
      Delayed::Worker.new.work_off
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 1
    end
  end

  describe 'select question' do
    describe 'when enrolled in course' do
      it 'selects correct lesson from course' do
        lessons = course.lessons.sort
        lessons.first.questions.sort[0..1].each { |question| create(:email_response, user: emailer, in_reply_to_user: asker, in_reply_to_question: question, correct: true) }
        create(:email_response, user: emailer, in_reply_to_user: asker, in_reply_to_question: lessons[1].questions.first, correct: true)
        asker.becomes(EmailAsker).select_lesson(emailer, course).must_equal(lessons.first)
      end

      it 'selects next lesson when last is completed' do
        lessons = course.lessons.sort
        lessons.first.questions.each { |question| create(:email_response, user: emailer, in_reply_to_user: asker, in_reply_to_question: question, correct: true) }
        asker.becomes(EmailAsker).select_lesson(emailer, course).must_equal(lessons[1])
      end

      it 'selects next question in lesson' do
        lesson = course.lessons.sort.first
        lesson.questions.sort[0..1].each { |question| create(:email_response, user: emailer, in_reply_to_user: asker, in_reply_to_question: question, correct: true) }
        asker.becomes(EmailAsker).select_question(emailer).must_equal(lesson.questions.sort.last)
      end
    end
  end

  describe 'course' do
    let(:email_body) {ActionMailer::Base.deliveries.first.body}
    let(:lesson_one_questions) {lessons[0].questions}
    let(:lesson_two_questions) {lessons[1].questions}

    it 'contains course name' do
      email_body.include?(course.name).must_equal true
    end

    it 'contains lesson list' do
      email_body.include?(lessons[0].name).must_equal true
      email_body.include?(lessons[1].name).must_equal true
      email_body.include?(lessons[2].name).must_equal true
    end

    it 'shows completed lessons' do
      lesson_one_questions.each {|q| create(:post, user: emailer, in_reply_to_user_id: asker.id, correct: true, interaction_type: 5, in_reply_to_question: q)}
      Timecop.travel 3.days
      Asker.reengage_inactive_users strategy: strategy
      email_body = ActionMailer::Base.deliveries.last.body
      email_body.include?("#{lessons[0].name} (100%)").must_equal true
    end

    it 'shows progress on current lesson' do
      lesson_one_questions.each {|q| create(:post, user: emailer, in_reply_to_user_id: asker.id, correct: true, interaction_type: 5, in_reply_to_question: q)}
      lesson_two_questions[0..1].each {|q| create(:post, user: emailer, in_reply_to_user_id: asker.id, correct: true, interaction_type: 5, in_reply_to_question: q)}
      Timecop.travel 3.days
      Asker.reengage_inactive_users strategy: strategy
      email_body = ActionMailer::Base.deliveries.last.body
      email_body.include?("#{lessons[1].name} (67%)").must_equal true
    end
  end
end
