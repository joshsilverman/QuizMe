require 'test_helper'

describe IssuancesController, "#show" do
  it "must return 200" do
    issuance = Issuance.create

    get :show, id: issuance.id

    response.status.must_equal 200
  end
end