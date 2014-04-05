require 'test_helper'

describe TopicsController do
  describe "#index" do
    it "returns status 200" do
      asker = create :asker
      get :index, format: :json, asker_id: asker.id

      response.status.must_equal 200
    end

    it "returns json with all topics" do
      asker = create :asker
      create(:lesson).askers << asker
      create(:lesson).askers << asker

      get :index, format: :json, asker_id: asker.id

      JSON.parse(response.body).count.must_equal 2
    end

    it "returns json with only lessons" do
      asker = create :asker
      create(:topic).askers << asker
      create(:lesson).askers << asker

      get :index, format: :json, asker_id: asker.id, scope: 'lessons'

      JSON.parse(response.body).count.must_equal 1
    end
  end

  describe "#show" do
    it "returns status 200" do
      asker = create :asker, subject: 'biology'
      get :show, subject: 'biology', name: 'mitosis'

      response.status.must_equal 200
    end

    it "returns lesson with questions json" do
      asker = create :asker, subject: 'biology'
      lesson = create(:lesson, :with_questions)
      lesson.askers << asker

      get :show, subject: 'biology', name: lesson.name, format: :json
      question_json = JSON.parse(response.body)

      question_json.count.must_equal 3
    end
  end
end