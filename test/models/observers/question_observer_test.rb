require 'test_helper'

describe Question, "QuestionObserver#after_create" do

  let(:asker) { create(:asker) }
  let(:question_with_user) { create(:question, asker: asker, user_id: 123) }
  let(:question_without_user) { create(:question, asker: asker) }

  before do
    ActiveRecord::Base.observers.enable :question_observer
  end

  it "calls request_feedback_on_question" do
    Delayed::Worker.delay_jobs = false
    Asker.any_instance.expects :request_feedback_on_question

    question_with_user
  end

  it "wont call request_feedback_on_question if no user id" do
    Delayed::Worker.delay_jobs = false
    Asker.any_instance.expects(:request_feedback_on_question).never
    
    question_without_user
  end
end