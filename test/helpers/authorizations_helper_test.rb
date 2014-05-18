require 'test_helper'

describe AuthorizationsHelper, "description" do
  include AuthorizationsHelper

  it "return url with expireable auth token" do
    link = 'http://www.google.com'
    user = create :user
    expires_at = Time.now + 10.years

    link_with_query_string = authenticated_link link, user, expires_at
    url = URI(link_with_query_string)
    params = Rack::Utils.parse_query(url.query)

    link_with_query_string.must_be_kind_of String
    params["a"].wont_be_nil
  end

  it "creates auth token for user if none exists" do
    link = 'http://www.google.com'
    user = create :user
    expires_at = Time.now + 10.years

    user.authentication_token.must_be_nil

    authenticated_link link, user, expires_at

    user.authentication_token.wont_be_nil
  end
end