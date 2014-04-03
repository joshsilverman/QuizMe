require 'test_helper'

describe AnswerObserver, "#after_save" do
  before :each do
    ActiveRecord::Base.observers.disable :all
    ActiveRecord::Base.observers.enable :answer_observer
  end

  it "calls #update_answers" do
    question = FactoryGirl.create :question
    Question.last._answers.wont_be_nil
  end
end