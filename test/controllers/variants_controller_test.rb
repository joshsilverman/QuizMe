require 'test_helper'

describe VariantsController, "#current" do
  it 'returns variant when a variant has been set' do
    get :current, variant: 'phone'

    JSON.parse(response.body)['name'].must_equal 'phone'
  end

  it 'returns empty string when variant has not been set' do
    get :current

    JSON.parse(response.body)['name'].must_equal nil
  end
end
