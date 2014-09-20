require 'test_helper'

describe VariantsController, "#current" do
  it 'returns variant when a variant has been set' do
    get :current, variant: 'phone'

    response.body.must_equal 'phone'
  end

  it 'returns empty string when variant has not been set' do
    get :current

    response.body.must_equal ''
  end
end
