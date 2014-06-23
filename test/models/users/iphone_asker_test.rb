require 'test_helper'

describe IphoneAsker do
  let(:asker) do 
    asker = create :asker
    asker.followers << iphoner
    asker
  end
  let(:iphoner) {create(:iphoner, twi_user_id: 1)}
  let(:non_iphoner) {create(:user)}
  let(:question) {create(:question, created_for_asker_id: asker.id, status: 1)}
  let(:strategy) {[1, 2, 4, 8]}
  let(:publication) {create(:publication, question_id: question.id)}

  before :each do
    @question_status = create(:post, user_id: asker.id, interaction_type: 1, question_id: question.id, publication_id: publication.id)   

    # @iphoner_response = create(:post, text: 'the correct answer, yo', user_id: iphoner.id, in_reply_to_user_id: asker.id, interaction_type: 5, in_reply_to_question_id: question.id)
    # @iphoner_response.update_attributes created_at: (strategy.first + 1).days.ago, correct: true
    # iphoner.update_attributes last_answer_at: @iphoner_response.created_at, last_interaction_at: @iphoner_response.created_at, activity_segment: nil
    # create(:post, in_reply_to_user_id: asker.id, correct: true, interaction_type: 2, in_reply_to_question_id: question.id)

    Delayed::Worker.delay_jobs = false
    Asker.reengage_inactive_users strategy: strategy
  end

  describe 'public send' do
    it 'wont send' do
      asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner).count.must_equal 0
    end
  end

  describe 'private send' do
    it 'wont send' do
      asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner).count.must_equal 0
    end

    it 'sends if communication preference changes' do
      iphoner.update communication_preference: 1
      asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner).count.must_equal 1
    end    

    # it 'is used when communication preference is set for email' do
    #   iphoner.communication_preference.must_equal 2
    #   asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner.reload).first.interaction_type.must_equal 5
    # end

    # it 'is not used when communication preference is set for Twitter' do
    #   iphoner.update_attributes communication_preference: 1
    #   Timecop.travel 3.days
    #   Asker.reengage_inactive_users strategy: strategy
    #   posts = asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner).sort
    #   posts.count.must_equal 2
    #   posts.last.interaction_type.wont_equal 5
    #   ActionMailer::Base.deliveries.count.must_equal 1
    # end

    # it 'will cause email delivery' do
    #   ActionMailer::Base.deliveries.wont_be_empty
    # end
  end

  # describe 'follows up on correct answer' do
  #   before :each do 
  #     @question_email = create(:email, user_id: asker.id, question_id: question.id, publication_id: publication.id, in_reply_to_user_id: iphoner.id)
  #     @conversation = create(:conversation, post: @question_email, publication: publication)
  #     Delayed::Worker.delay_jobs = true
  #   end

  #   it 'only on correct answers' do
  #     @conversation.posts << response = create(:email, in_reply_to_question_id: question.id, in_reply_to_post_id: @question_email.id, autocorrect: false, requires_action: true)
  #     asker.auto_respond(response, iphoner)
  #     asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
  #     Timecop.travel(Time.now + 1.day)
  #     Delayed::Worker.new.work_off
  #     asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
  #   end

  #   it 'one day later' do
  #     @conversation.posts << response = create(:email, in_reply_to_question_id: question.id, in_reply_to_post_id: @question_email.id, autocorrect: true, requires_action: true)
  #     asker.auto_respond(response, iphoner)
  #     asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
  #     Timecop.travel(Time.now + 1.day)
  #     Delayed::Worker.new.work_off
  #     asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 1      
  #   end

  #   it 'only if email version' do
  #     @conversation = FactoryGirl.create(:conversation, publication_id: publication.id)
  #     @user_response = FactoryGirl.create(:post, text: 'the incorrect answer', user_id: iphoner.id, in_reply_to_user_id: asker.id, interaction_type: 2, in_reply_to_question_id: question.id, in_reply_to_post_id: @question_status.id)
  #     @conversation.posts << @user_response     

  #     asker.posts.where("intention = 'correct answer follow up' and in_reply_to_user_id = ?", iphoner.id).count.must_equal 0
  #     asker.app_response @user_response, true
  #     16.times do
  #       Delayed::Worker.new.work_off
  #       Timecop.travel(Time.now + 1.day)
  #     end
  #     asker.posts.where("intention = 'correct answer follow up' and in_reply_to_user_id = ?", iphoner.id).count.must_equal 0
  #   end

  #   it 'unless is a followup' do
  #     @conversation.posts << response = create(:email, in_reply_to_question_id: question.id, in_reply_to_post_id: @question_email.id, autocorrect: true, requires_action: true)
  #     asker.auto_respond(response, iphoner)
  #     asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
  #     Timecop.travel(Time.now + 1.day)
  #     Delayed::Worker.new.work_off
  #     asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 1      

  #     followup = asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').first
  #     @conversation.posts << response = create(:email, in_reply_to_question_id: question.id, in_reply_to_post_id: followup.id, autocorrect: true, requires_action: true)
  #     asker.auto_respond(response, iphoner)
  #     Timecop.travel(Time.now + 1.day)
  #     Delayed::Worker.new.work_off
  #     asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 1
  #   end
  # end
end