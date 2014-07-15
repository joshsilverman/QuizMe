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
  let(:asker) { create :asker }
  let(:question) { create :question }
  let(:post) { create :post, 
    correct: :true, 
    in_reply_to_user_id: user.id,
    user_id: asker.id,
    intention: 'reengage inactive',
    question_id: question.id }

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

    json = JSON.parse response.body

    json.count.must_equal 1
    json.first['asker_id'].must_equal asker.id
    json.first['_answers'].values.must_include 'the correct answer'
    json.first['_question']['text'].must_be_kind_of String
    json.first['_question']['id'].must_equal question.id

    1.must_equal 2
  end
end