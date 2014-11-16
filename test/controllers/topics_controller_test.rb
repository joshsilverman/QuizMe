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

describe TopicsController, "#create" do
  let(:user) { create :user }

  it "creates new lesson with correct fkeys" do
    sign_in user

    get :create, format: :json, asker_id: 123, name: 'hello', type_id: 6

    quiz = Topic.lessons.first

    response.status.must_equal 200
    Topic.lessons.count.must_equal 1
    quiz.type_id.must_equal 6
    quiz.user_id.must_equal user.id
    quiz.asker_id.must_equal 123
  end

  it "401's if not authed" do
    get :create, format: :json, asker_id: 123, name: 'hello', type_id: 6

    response.status.must_equal 401
  end

  it "marks as not yet published" do
    sign_in user

    get :create, format: :json, asker_id: 123, name: 'hello', type_id: 6
    response.status.must_equal 200

    Topic.lessons.last.published.must_equal false
  end

  it "returns id" do
    sign_in user

    get :create, format: :json, asker_id: 123, name: 'hello', type_id: 6

    quiz = Topic.lessons.first

    new_quiz_hash = JSON.parse(response.body)
    new_quiz_hash['id'].wont_be_nil
  end
end

describe TopicsController, "#update" do
  let(:user) { create :user }
  let(:quiz) { create :lesson }

  it "updates lesson name" do
    sign_in user

    patch :update, format: :json, name: 'hello', id: quiz.id

    response.status.must_equal 200
    Topic.lessons.count.must_equal 1
    quiz.reload.name.must_equal 'hello'
  end

  it "wont save unpermitted params" do
    sign_in user

    patch :update, format: :json, type_id: 5, id: quiz.id

    response.status.must_equal 200
    Topic.lessons.count.must_equal 1
    quiz.reload.type_id.must_equal 6
  end

  it "401's if not authed" do
    patch :update, format: :json, name: 'hello', id: quiz.id

    response.status.must_equal 401
  end
end