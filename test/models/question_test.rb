require 'test_helper'

describe Question, "#update_answers" do
  it "stores answer in _answers attr" do
    question = create :question
    correct_answer = question.answers.correct

    question.update_answers

    question._answers.count.wont_be_nil
    question._answers.count.must_be :>, 0
    question._correct_answer_id.must_equal correct_answer.id
  end
end