require 'test_helper'

describe AskersController do

  let(:course) {create(:course, :with_lessons)}
  let(:asker) { course.askers.first }
  let(:strategy) {[1, 2, 4, 8]}
  let(:emailer) do 
    emailer = create(:emailer)
    asker.followers << emailer
    emailer
  end
  let(:non_emailer) do 
    non_emailer = create(:user)
    asker.followers << non_emailer
    non_emailer
  end
  let(:author) {create(:user)}
  let(:question) {asker.questions.first}
  let(:publication) {create(:publication, question_id: question.id)}
  let(:reengage_inactive_post) {create(:post, user_id: asker.id, interaction_type: 5, question_id: question.id, publication_id: publication.id, in_reply_to_user: emailer)}
  let(:user_response) {create(:post, user_id: emailer.id, in_reply_to_user_id: asker.id, interaction_type: 5, in_reply_to_question_id: question.id, correct: true)}  

  describe 'reengages inactive' do
    it 'emailer with correct question' do
      lesson = course.lessons.sort.first
      lesson.questions.sort[0..1].each { |question| create(:email_response, user: emailer, in_reply_to_user: asker, in_reply_to_question: question, correct: true) }  
      Timecop.travel(Time.now + 1.day)
      Asker.reengage_inactive_users strategy: strategy
      reengage_inactive_post = Post.reengage_inactive.where("user_id = ? and in_reply_to_user_id = ?", asker.id, emailer.id).first
      reengage_inactive_post.question_id.must_equal lesson.questions.sort[2].id
    end

    it 'non emailer with correct question' do
      create(:post, user_id: asker.id, interaction_type: 1, question_id: question.id, publication_id: publication.id)   
      lesson = course.lessons.sort.first
      lesson.questions.sort[0..1].each { |question| create(:email_response, user: non_emailer, in_reply_to_user: asker, in_reply_to_question: question, correct: true) }  
      course.lessons[1].questions.first.update(user_id: author.id)
      Timecop.travel(Time.now + 1.day)
      Asker.reengage_inactive_users strategy: strategy
      reengage_inactive_post = Post.reengage_inactive.where("user_id = ? and in_reply_to_user_id = ?", asker.id, non_emailer.id).first
      reengage_inactive_post.question_id.wont_equal lesson.questions.sort[2].id      
    end
  end
end