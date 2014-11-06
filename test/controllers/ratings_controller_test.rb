require 'test_helper'

describe RatingsController, '#create' do
  let(:user) { create :user }
  let(:question) { create :question }

  it "creates a rating with correct params" do
    sign_in user

    post :create, question_id: question.id, score: 5

    Rating.count.must_equal 1
    Rating.last.question_id.must_equal question.id
    Rating.last.user_id.must_equal user.id
    Rating.last.score.must_equal 5

    response.status.must_equal 200
  end

  it "redirects if not authenticated" do
    post :create, question_id: question.id, score: 5

    response.status.must_equal 302
  end

  it "wont create multiple ratings for one user-question" do
    sign_in user

    post :create, question_id: question.id, score: 5
    post :create, question_id: question.id, score: 4

    Rating.count.must_equal 1
  end

  it "updates existng rating if exists" do
    sign_in user

    post :create, question_id: question.id, score: 5
    post :create, question_id: question.id, score: 4

    Rating.count.must_equal 1
    Rating.last.score.must_equal 4
  end
end