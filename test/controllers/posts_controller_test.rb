require 'test_helper'

describe PostsController, "#answer_count" do
  it "return the number of questions answered" do
    user = create :user
    post = create :post, correct: :true, user_id: user.id

    get :answer_count, user_id: user.id, format: :json
    response.body.must_equal("1")
  end
end

describe PostsController, "#reengage_inactive" do
  let(:user) { create :user }
  let(:post) { create :post, correct: :true, user_id: user.id }

  it "returns error if no user authenticated" do
    post

    get :reengage_inactive, format: :json
    response.status.must_equal(401)
  end

  it "returns last n reengage inactive posts" do
    post
    sign_in user

    get :reengage_inactive, format: :json
    response.status.must_equal(200)
  end
end