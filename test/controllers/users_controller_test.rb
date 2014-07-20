require 'test_helper'

describe UsersController, '#correct_question_ids' do
  it 'returns an array of question ids' do
    user = create :user
    question = create :question
    correct_response = create :correct_response, 
      user: user,
      in_reply_to_question: question

    sign_in user
    get :correct_question_ids, user_id: user.id, format: :json

    response.status.must_equal 200
    JSON.parse(response.body).must_equal [question.id]
  end

  it 'returns an array of question ids' do
    user = create :user
    question = create :question

    incorrect_response = create :incorrect_response, 
      user: user,
      in_reply_to_question: question
    correct_response = create :correct_response, 
      user: user,
      in_reply_to_question: question

    sign_in user
    get :correct_question_ids, user_id: user.id, format: :json

    response.status.must_equal 200
    JSON.parse(response.body).must_equal [question.id]
  end

  it 'redirects if user not authenticated' do
    user = create :user

    get :correct_question_ids, user_id: user.id, format: :json

    response.status.must_equal 401
  end

  it 'wont include correct response with no linked question' do
    user = create :user
    correct_response = create :correct_response, user: user

    sign_in user
    get :correct_question_ids, user_id: user.id, format: :json

    JSON.parse(response.body).must_equal []
  end
end

describe UsersController, "#wisr_follow_ids" do
  let(:user) { create :user }
  let(:asker) { create :asker }

  it "returns list of follow ids" do
    sign_in user

    Relationship.create({
      followed_id: asker.id,
      follower_id: user.id,
      channel: Relationship::WISR})

    get :wisr_follow_ids, format: :json
    returned_ids = JSON.parse response.body

    response.status.must_equal 200
    returned_ids.count.must_equal 1
    returned_ids.first.must_equal asker.id
  end

  it "wont return followers followed via twitter channel" do
    sign_in user

    Relationship.create({
      followed_id: asker.id,
      follower_id: user.id,
      channel: Relationship::TWITTER})

    get :wisr_follow_ids, format: :json
    returned_ids = JSON.parse response.body

    response.status.must_equal 200
    returned_ids.count.must_equal 0
  end

  it "wont return inactive relationships" do
    sign_in user

    Relationship.create({
      followed_id: asker.id,
      follower_id: user.id,
      active: false,
      channel: Relationship::WISR})

    get :wisr_follow_ids, format: :json
    returned_ids = JSON.parse response.body

    response.status.must_equal 200
    returned_ids.count.must_equal 0
  end

  it "redirects if not authenticated" do
    Relationship.create({
      followed_id: asker.id,
      follower_id: user.id,
      active: false,
      channel: Relationship::WISR})

    get :wisr_follow_ids, format: :json

    response.status.must_equal 401
  end
end

describe UsersController, "#auth_token" do
  let(:user) { create :user }

  it "returns 200 if user authenticated" do
    sign_in user
    get :auth_token
    response.status.must_equal 200
  end

  it "redirects if user not authenticated" do
    get :auth_token
    response.status.must_equal 302
  end
end

describe UsersController, '#register_device_token' do
  let(:user) { create :user }

  it 'persists device_token' do
    sign_in user
    post :register_device_token, token: 'abc'

    response.status.must_equal 200
    user.reload.device_token.must_equal 'abc'
  end

  it 'changes communication_preference to iphoner' do
    sign_in user
    user.communication_preference.wont_equal 3

    post :register_device_token, token: 'abc'

    user.reload.communication_preference.must_equal 3
    user.reload.device_token.must_equal 'abc'
  end

  it 'wont persist if nil' do
    sign_in user
    user.communication_preference.must_equal 1

    post :register_device_token

    user.reload.communication_preference.must_equal 1
    user.reload.device_token.must_equal nil
  end

  it 'returns error status if not authenticated' do
    post :register_device_token, token: 'abc'
    response.status.must_equal 302
  end
end