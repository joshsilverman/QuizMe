require 'test_helper'

describe IssuancesController, "#show" do
  it "must return 200" do
    issuance = Issuance.create

    get :show, id: issuance.id

    response.status.must_equal 200
  end
end

describe IssuancesController, "#index" do
  it "must return 200" do
    issuance = Issuance.create
    user = User.create
    sign_in user

    get :index, format: :json

    response.status.must_equal 200
  end
end