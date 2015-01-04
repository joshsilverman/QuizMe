require 'test_helper'

describe LessonsController, "#show" do
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

describe LessonsController, "#create" do
  let(:user) { create :user }
  let(:asker) { create :asker }

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

  it "creates first question" do
    sign_in user
    ActiveRecord::Base.observers.enable :answer_observer

    get :create, format: :json, asker_id: asker.id, name: 'hello', type_id: 6
    response.status.must_equal 200

    Topic.lessons.count.must_equal 1
    quiz = Topic.lessons.last
    quiz.published.must_equal false
    quiz.questions.count.must_equal 1

    question = quiz.questions.first
    question.user.must_equal user
    question.asker.must_equal asker
    question.answers.correct.wont_be_nil
    question.answers.incorrect.count.must_equal 1
    question._answers.wont_be_nil
  end
end

describe LessonsController, "#update" do
  let(:user) { create :user }
  let(:hacker) { create :user }
  let(:admin) { create :admin }
  let(:quiz) { create :lesson, user_id: user.id }

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

  it "wont allow non owner non admin to edit title" do
    sign_in hacker

    patch :update, format: :json, name: 'hello', id: quiz.id

    response.status.must_equal 401
    Topic.lessons.count.must_equal 1
    quiz.reload.name.wont_equal 'hello'
  end

  it "allows non owner but admin to edit" do
    sign_in admin

    patch :update, format: :json, name: 'hello', id: quiz.id

    response.status.must_equal 200
    Topic.lessons.count.must_equal 1
    quiz.reload.name.must_equal 'hello'
  end
end