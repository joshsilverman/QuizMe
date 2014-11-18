require 'test_helper'

describe TopicsController, "#index" do
  it "returns status 200" do
    asker = create :asker
    get :index, format: :json, asker_id: asker.id

    response.status.must_equal 200
  end

  it "returns json with all topics" do
    asker = create :asker
    create(:lesson).askers << asker
    create(:lesson).askers << asker
    create(:lesson).askers << asker

    get :index, format: :json, asker_id: asker.id

    JSON.parse(response.body)["topics"].count.must_equal 3
  end

  it "returns json with only lessons" do
    asker = create :asker
    create(:topic).askers << asker
    create(:lesson).askers << asker

    get :index, format: :json, asker_id: asker.id, scope: 'lessons'

    JSON.parse(response.body)["topics"].count.must_equal 1
  end
end

describe TopicsController, "#show" do
  it "redirects to ng" do
    get :show, subject: 'biology', name: 'cats'
    response.status.must_equal 301
  end

  it "returns lesson with questions json when queried with subject" do
    asker = create :asker, subject: 'biology'
    lesson = create(:lesson, :with_questions)
    lesson.askers << asker

    get :show, subject: 'biology', name: lesson.name, format: :json
    question_json = JSON.parse(response.body)

    question_json.count.must_equal 3
  end

  it "returns lesson with questions json when queried with id" do
    asker = create :asker, subject: 'biology'
    lesson = create(:lesson, :with_questions)
    lesson.askers << asker

    get :show, id: lesson.id, format: :json
    question_json = JSON.parse(response.body)

    question_json.count.must_equal 3
  end

  it "returns lesson with empty questions when no questions" do
    asker = create :asker, subject: 'biology'
    lesson = create(:lesson)
    lesson.askers << asker

    get :show, id: lesson.id, format: :json
    question_json = JSON.parse(response.body)

    question_json.count.must_equal 0
  end
end

describe TopicsController, "#answered_counts" do
  it "responds to json" do
    user = create :user
    sign_in user

    get :answered_counts, format: :json

    response.status.must_equal 200
  end

  it "responds with count if question answered in lesson" do
    user = create :user
    lesson = create :lesson, :with_questions
    question = lesson.questions.first
    correct_response = create :correct_response,
      in_reply_to_question: question,
      user: user

    sign_in user

    get :answered_counts, format: :json
    answered_counts = JSON.parse(response.body)

    answered_counts.count.must_equal 1
    answered_counts.values.first.must_equal 1
  end

  it "responds with count if multiple questions answered in lesson" do
    user = create :user
    lesson = create :lesson, :with_questions
    question1 = lesson.questions[0]
    question2 = lesson.questions[1]

    correct_response1 = create :correct_response,
      in_reply_to_question: question1,
      user: user

    correct_response2 = create :correct_response,
      in_reply_to_question: question2,
      user: user

    sign_in user

    get :answered_counts, format: :json
    answered_counts = JSON.parse(response.body)

    answered_counts.count.must_equal 1
    answered_counts.values.first.must_equal 2
  end

  it "wont count duplicate answers to same question lesson" do
    user = create :user
    lesson = create :lesson, :with_questions
    question = lesson.questions[0]

    correct_response1 = create :correct_response,
      in_reply_to_question: question,
      user: user

    correct_response2 = create :correct_response,
      in_reply_to_question: question,
      user: user

    sign_in user

    get :answered_counts, format: :json
    answered_counts = JSON.parse(response.body)

    answered_counts.count.must_equal 1
    answered_counts.values.first.must_equal 1
  end

  it "redirects if no current user" do
    get :answered_counts, format: :json

    response.status.must_equal 401
  end
end