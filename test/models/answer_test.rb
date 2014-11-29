require 'test_helper'

describe Answer, "#save" do
  let(:question) { Question.create! }

  it "must be associated with question" do
    answer = Answer.new
    answer.valid?.must_equal false

    answer.question_id = 123
    answer.valid?.must_equal true
  end

  it "valid if single correct answers on question" do
    answer = Answer.create question: question, correct: true
    answer.valid?.must_equal true
  end

  it "invalid if multiple correct answers on question" do
    Answer.create question: question, correct: true

    answer = Answer.new question: question, correct: true
    answer.valid?.must_equal false
    answer.errors[:correct].wont_be_nil
  end
end