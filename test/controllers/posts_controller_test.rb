require 'test_helper'

describe PostsController, "#answer_count" do
  it "return the number of questions answered" do
    user = create :user
    post = create :post, correct: :true, user_id: user.id

    get :answer_count, user_id: user.id, format: :json
    response.body.must_equal("1")
  end
end