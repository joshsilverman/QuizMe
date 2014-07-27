require 'test_helper'

describe IphoneAsker do
  let(:asker) do
    asker = create(:asker).becomes(IphoneAsker)
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

    @iphoner_response = create(:post, 
        text: 'the correct answer, yo', 
        user_id: iphoner.id, 
        in_reply_to_user_id: asker.id, 
        interaction_type: 2, 
        in_reply_to_question_id: question.id)

    @iphoner_response.update_attributes(
        created_at: (strategy.first + 1).days.ago, 
        correct: true)

    iphoner.update_attributes(
        last_answer_at: @iphoner_response.created_at, 
        last_interaction_at: @iphoner_response.created_at, 
        activity_segment: nil)

    create(:post, 
        in_reply_to_user_id: asker.id, 
        correct: true, 
        interaction_type: 2, 
        in_reply_to_question_id: question.id)

    Delayed::Worker.delay_jobs = false
  end

  describe '#send_public_message' do
    it 'wont send push notification if no device token' do
      iphoner.update device_token: nil

      Asker.reengage_inactive_users strategy: strategy
      asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner).count.must_equal 0
    end

    it 'will send push notification' do
      iphoner.update device_token: '<08a26d39 05745ffc f0e98d05 65ce8764 d03bae59 6f1f09f2 f4848a52 099b2f91>'

      Asker.reengage_inactive_users strategy: strategy
      asker.posts.reengage_inactive.apns.where(in_reply_to_user_id: iphoner).count.must_equal 1
    end

    it 'wont send if intention is to send aggregate activity' do
      iphoner.update device_token: 'abc'

      asker.send_public_message 'abc', {intention: 'post aggregate activity'}, iphoner
      asker.posts.apns.where(in_reply_to_user_id: iphoner).count.must_equal 0
    end

    it 'will send if intention is to reengage' do
      iphoner.update device_token: 'abc'

      asker.send_public_message 'abc', {intention: 'reengage inactive'}, iphoner
      asker.posts.apns.where(in_reply_to_user_id: iphoner).count.must_equal 1
    end

    it 'will send if intention is to followup on incorrect answer' do
      iphoner.update device_token: 'abc'

      asker.send_public_message 'abc', {intention: "incorrect answer follow up"}, iphoner
      asker.posts.apns.where(in_reply_to_user_id: iphoner).count.must_equal 1
    end
  end

  describe '#send_private_message' do
    it 'will push to APNS' do
      iphoner.update device_token: '<08a26d39 05745ffc f0e98d05 65ce8764 d03bae59 6f1f09f2 f4848a52 099b2f91>'

      APN.expects :push

      Asker.reengage_inactive_users strategy: strategy
    end

    it 'will create new reengage_inactive post' do
      iphoner.update device_token: '<08a26d39 05745ffc f0e98d05 65ce8764 d03bae59 6f1f09f2 f4848a52 099b2f91>'

      APN.stubs :push
      
      Asker.reengage_inactive_users strategy: strategy
      asker.posts.reengage_inactive.apns.where(in_reply_to_user_id: iphoner).count.must_equal 1
    end


    it 'wont create new reengage_inactive post or push if no device_token' do
      iphoner.update device_token: nil

      APN.expects(:push).never
      
      Asker.reengage_inactive_users strategy: strategy
      asker.posts.reengage_inactive.apns.where(in_reply_to_user_id: iphoner).count.must_equal 0
    end

    it 'sends if communication preference changes' do
      iphoner.update device_token: nil
      iphoner.update communication_preference: 1

      Asker.reengage_inactive_users strategy: strategy
      asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner.reload).count.must_equal 1
    end    
  end

  describe 'follows up on correct answer' do
    let(:publication) { create(:publication, question_id: question.id) }

    before :each do 
      @conversation = create(:conversation, publication_id: publication.id)
      @user_response = create(:post, 
          text: 'the incorrect answer', 
          user_id: iphoner.id, 
          in_reply_to_user_id: asker.id, 
          interaction_type: 2, 
          in_reply_to_question_id: question.id)
      @conversation.posts << @user_response

      Delayed::Worker.delay_jobs = true
      Delayed::Worker.new.work_off
    end

    it 'never' do
      asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", iphoner.id).count.must_equal 0
      asker.app_response @user_response, false
      16.times do
        Delayed::Worker.new.work_off
        Timecop.travel(Time.now + 1.day)
      end
      asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", iphoner.id).count.must_equal 0
    end

    it 'if user changes communication preference' do
      iphoner.update communication_preference: 1
      asker = Asker.last

      asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", iphoner.id).count.must_equal 0
      asker.app_response @user_response, false
      16.times do
        Delayed::Worker.new.work_off
        Timecop.travel(Time.now + 1.day)
      end
      asker.posts.where("intention = 'incorrect answer follow up' and in_reply_to_user_id = ?", iphoner.id).count.must_equal 1
    end
  end
end