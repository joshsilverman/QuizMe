require 'test_helper'

describe Rating, "RatingObserver#after_save" do
  let(:user) { create :user }
  let(:asker) { create :asker }
  let(:question) { create :question, asker: asker }
  let(:publication) { create :publication, question: question }

  before :each do
    ActiveRecord::Base.observers.disable :all
    ActiveRecord::Base.observers.enable :rating_observer
  end

  it "calls #update_rating" do
    question
    rating = Rating.create!(
      question_id: question.id, 
      user_id: user.id,
      score: 3)

    Delayed::Worker.new.work_off
    
    Question.last._rating['score'].must_equal '3.0'
    Question.last._rating['count'].must_equal '1'
  end

  it "updates latest publication rating" do
    publication
    rating = Rating.create!(
      question_id: question.id, 
      user_id: user.id,
      score: 3)

    Delayed::Worker.new.work_off
    
    publication.reload._question['rating'].must_equal '3.0'
  end
end