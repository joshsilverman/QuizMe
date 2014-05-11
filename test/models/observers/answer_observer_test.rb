require 'test_helper'

describe Answer, "AnswerObserver#after_save" do
  before :each do
    ActiveRecord::Base.observers.disable :all
    ActiveRecord::Base.observers.enable :answer_observer
  end

  it "calls #update_answers" do
    question = Question.create
    answer = Answer.create
    question.answers << answer

    Delayed::Worker.new.work_off
    
    Question.last._answers.wont_be_nil
  end

  it "wont call #update_answers if answer has no question" do
    question = Question.create
    answer = Answer.create
    
    Delayed::Worker.new.work_off
    
    Question.last._answers.must_be_nil
  end  
end