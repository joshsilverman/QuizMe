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
    it 'wont send' do
      Asker.reengage_inactive_users strategy: strategy
      asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner).count.must_equal 0
    end
  end

  describe '#send_private_message' do
    it 'wont send' do
      Asker.reengage_inactive_users strategy: strategy
      asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner).count.must_equal 0
    end

    it 'sends if communication preference changes' do
      iphoner.update communication_preference: 1
      Asker.reengage_inactive_users strategy: strategy
      asker.posts.reengage_inactive.where(in_reply_to_user_id: iphoner.reload).count.must_equal 1
    end    
  end

  describe 'follows up on correct answer' do
    before :each do 
      @question_email = create(:email, user_id: asker.id, question_id: question.id, publication_id: publication.id, in_reply_to_user_id: iphoner.id)
      @conversation = create(:conversation, post: @question_email, publication: publication)
      Delayed::Worker.delay_jobs = true
    end

    it 'if user changes communication preference' do
      @iphoner_response.update correct: false, autocorrect: false
      @conversation.posts << response
      asker.auto_respond(response, iphoner)
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
      Timecop.travel(Time.now + 1.day)
      Delayed::Worker.new.work_off
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
    end


    it 'with tweet' do
      iphoner.update communication_preference: 1

      @iphoner_response.update correct: false, autocorrect: false
      @conversation.posts << response
      asker.auto_respond(response, iphoner)
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 0
      Timecop.travel(Time.now + 1.day)
      Delayed::Worker.new.work_off
      asker.reload.posts.where(question_id: question.id, intention: 'correct answer follow up').count.must_equal 1      
    end
  end
end