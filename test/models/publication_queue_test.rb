require 'test_helper'

describe PublicationQueue, ".enqueue_questions" do
  it "has correct basic attrs" do
    asker = Asker.create
    question = Question.create text: 'What up?', asker: asker
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker

    Publication.count.must_equal 1
    Publication.first.question_id.must_equal question.id
    Publication.first.asker_id.must_equal asker.id
  end

  it "stores question in hstore cache" do
    asker = Asker.create
    question = Question.create text: 'What up?', asker: asker
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker

    Publication.count.must_equal 1
    Publication.first._question['question'].must_equal question.text
  end

  it "stores correct answer in hstore cache" do
    asker = Asker.create
    question = Question.create text: 'What up?', asker: asker
    answer = question.answers.create text: 'correct ans', correct: true
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker

    Publication.count.must_equal 1
    Publication.first._question['correct_answer'].must_equal answer.text
  end

  it "stores incorrect answers in hstore cache" do
    asker = Asker.create
    question = Question.create text: 'What up?', asker: asker
    ans_0 = question.answers.create text: 'incorrect ans 0', correct: false
    ans_1 = question.answers.create text: 'incorrect ans 1', correct: false
    ans_2 = question.answers.create text: 'incorrect ans 2', correct: false
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker

    Publication.count.must_equal 1
    Publication.first._question['incorrect_answer_0'].must_equal ans_0.text
    Publication.first._question['incorrect_answer_1'].must_equal ans_1.text
    Publication.first._question['incorrect_answer_2'].must_equal ans_2.text
  end
end