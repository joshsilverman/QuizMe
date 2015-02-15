require 'test_helper'

describe Topic, "#_question_count" do
  before do
    ActiveRecord::Base.observers.enable :questions_topic_observer
  end

  it "increments questions count cache" do
    question = Question.create status: 1
    topic = create :lesson

    topic._question_count.must_equal 0

    topic.questions << question
    topic.reload

    topic._question_count.must_equal 1
  end

  it "wont increment twice if same question is re-added" do
    question = Question.create status: 1
    topic = create :lesson

    topic._question_count.must_equal 0

    topic.questions << question
    -> { topic.questions << question }.must_raise ActiveRecord::RecordInvalid
    topic.reload

    topic.questions.count.must_equal 1
    QuestionsTopic.count.must_equal 1
    topic._question_count.must_equal 1
  end

  it "decrements question removed from collection" do
    Question.count.must_equal 0
    question = Question.create status: 1
    topic = create :lesson

    topic._question_count.must_equal 0

    topic.questions << question
    topic.questions.delete(question)
    topic.reload

    topic.questions.count.must_equal 0
    QuestionsTopic.count.must_equal 0
    topic._question_count.must_equal 0
    Question.count.must_equal 1
    Topic.count.must_equal 1
  end

  it "updates count if question destroyed" do
    Question.count.must_equal 0
    question = Question.create status: 1
    topic = create :lesson

    topic._question_count.must_equal 0

    topic.questions << question
    question.destroy
    topic.reload

    topic.questions.count.must_equal 0
    QuestionsTopic.count.must_equal 0
    topic._question_count.must_equal 0
    Question.count.must_equal 0
    Topic.count.must_equal 1
  end

  it "wont scope by question status" do
    question = Question.create status: 0
    topic = create :lesson

    topic._question_count.must_equal 0

    topic.questions << question
    topic.reload

    topic._question_count.must_equal 1
  end
end
