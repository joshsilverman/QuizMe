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
  before do
    ActiveRecord::Base.observers.enable :questions_topic_observer
    ActiveRecord::Base.observers.enable :question_observer
  end

  it "calls update_question on questions topics" do
    asker = create :asker
    lesson = create :lesson
    lesson.askers << asker
    question = create :question, :approved
    lesson.questions << question

    lesson.reload._question_count.must_equal 1

    question.update status: 0

    lesson.reload._question_count.must_equal 0
  end
end