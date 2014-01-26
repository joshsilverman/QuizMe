require 'test_helper'

describe Asker, "EngagementEngine::AutoRespond#auto_respond" do
  before :each do 
    @asker = create(:asker)
    @user = create(:user, twi_user_id: 1)

    @asker.followers << @user   

    @question = create(:question, created_for_asker_id: @asker.id, status: 1)
    @publication = create(:publication, question_id: @question.id)
    @question_status = create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)   
    Delayed::Worker.delay_jobs = false

    @conversation = create(:conversation, 
      post: @question_status, 
      publication: @publication)

    @conversation.posts << @user_response = create(:post, 
      text: 'the correct answer, yo', 
      user_id: @user.id, 
      in_reply_to_user_id: @asker.id, 
      interaction_type: 2, 
      in_reply_to_question_id: @question.id,
      parent: create(:dm, created_at: 1.hour.ago),
      requires_action: true, 
      autocorrect: nil)

    @correct = [1, 2].sample == 1

    @incorrect_answer = create(:answer, 
      correct: false, 
      text: 'the incorrect answer', 
      question_id: @question.id)
  end

  it 'automatically responds to autocorrected posts' do
    @user_response.update(
      requires_action: true, 
      autocorrect: true)

    @asker.auto_respond(@user_response)
    @user_response.reload.requires_action.must_equal false
    @asker.posts.where(
        intention: 'grade', 
        in_reply_to_post_id: @user_response.id)
      .count.must_equal 1
  end

  it 'wont respond to un-autocorrected posts' do
    @user_response.update(
      requires_action: true, 
      autocorrect: nil)

    @asker.auto_respond(@user_response)
    @user_response.reload.requires_action.must_equal true
    @asker.posts.where(
        intention: 'grade', 
        in_reply_to_post_id: @user_response.id)
      .count.must_equal 0
  end

  it 'automatically responds to dm answer' do
    @user_response.update(
      requires_action: true, 
      autocorrect: true,
      interaction_type: 4)

    @asker.auto_respond(@user_response)
    @user_response.reload.requires_action.must_equal false
    @asker.posts.where(
        intention: 'grade', 
        in_reply_to_post_id: @user_response.id)
      .count.must_equal 1
  end

  it 'wont respond multiple times with grade to the same dm answer' do
    @user_response.update(
      requires_action: true, 
      autocorrect: true,
      interaction_type: 4)

    @asker.auto_respond(@user_response)

    @conversation.posts << @user_response_2 = create(:post, 
      text: 'the correct answer again, dawg', 
      user_id: @user.id, 
      in_reply_to_user: @asker, 
      interaction_type: 4, 
      in_reply_to_question: @question,
      parent: @user_response.parent,
      requires_action: true,
      autocorrect: true)

    @asker.auto_respond(@user_response_2)
    
    @asker.posts.where(intention: 'grade').count.must_equal 1
  end

  it 'responds to multiple questions through dm' do
    @user_response.update(
      requires_action: true, 
      autocorrect: true,
      interaction_type: 4)

    @asker.auto_respond(@user_response)

    @conversation.posts << @user_response = create(:post, 
      text: 'the correct answer again, dawg', 
      user_id: @user.id, 
      in_reply_to_user_id: @asker.id, 
      interaction_type: 4, 
      in_reply_to_question: create(:question),
      parent: create(:dm, created_at: 1.hour.ago),
      requires_action: true,
      autocorrect: true)

    @asker.auto_respond(@user_response)
    
    @asker.posts.where(intention: 'grade').count.must_equal 2
  end
end