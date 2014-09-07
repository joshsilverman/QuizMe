require 'test_helper'

describe PublicationsController, "#show" do
  let (:publication) { create :publication }

  it "should respond to json format with pub json" do
    get :show, id: publication.id, format: :json

    json = JSON.parse(response.body)
    json['id'].must_equal publication.id
  end

  it "should respond 404 for invalid id" do
    get :show, id: 123, format: :json

    response.status.must_equal 404
  end
end
