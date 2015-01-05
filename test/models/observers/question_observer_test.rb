require 'test_helper'

describe Question, "QuestionObserver#after_create" do

  let(:asker) { create(:asker) }
  let(:question_with_user) { create(:question, asker: asker, user_id: 123) }
  let(:question_without_user) { create(:question, asker: asker) }

  before do
    ActiveRecord::Base.observers.enable :question_observer
  end

  it "calls post" do
    Delayed::Worker.delay_jobs = false
    Question.any_instance.expects :post

    question_with_user
  end

  it "wont call post if no user id" do
    Delayed::Worker.delay_jobs = false
    Question.any_instance.expects(:post).never
    
    question_without_user
  end
end

describe Question, "QuestionObserver#after_save" do
  let(:asker) { create :asker }
  let(:question) { create :question, :approved }

  before do
    ActiveRecord::Base.observers.enable :questions_topic_observer
    ActiveRecord::Base.observers.enable :question_observer
  end

  it "calls update_question on questions topics" do
    asker
    lesson = create :lesson
    lesson.askers << asker

    Question.any_instance.stubs :send_answer_counts_to_publication
    question
    
    lesson.reload._question_count.must_equal 0
    
    lesson.questions << question

    lesson.reload._question_count.must_equal 1
  end

  it "calls send_answer_counts_to_publication on save" do
    Question.any_instance.expects :send_answer_counts_to_publication
    question
  end
end