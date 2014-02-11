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