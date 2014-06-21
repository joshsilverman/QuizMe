require 'test_helper'

describe RegistrationsController, "create" do
  it "creates a new user" do
    @request.env["devise.mapping"] = Devise.mappings[:user]

    post(:create, user: {email: 'a@a.com', 
        password: 'abcabcabc', 
        password_confirmation: 'abcabcabc'})

    user = User.emailers.last
    user.wont_be_nil
    user.email.must_equal 'a@a.com'
  end

  it "creates user with com preference iphoner if sent from phone variant" do
    @request.env["devise.mapping"] = Devise.mappings[:user]

    post(:create, user: {email: 'b@b.com', 
        password: 'abcabcabc', 
        password_confirmation: 'abcabcabc'},
        variant: 'phone')

    user = User.iphoners.last
    user.wont_be_nil
    user.email.must_equal 'b@b.com'
  end

  it "wont change com pref if user doesnt save" do
    create :asker
    @request.env["devise.mapping"] = Devise.mappings[:user]

    post(:create, user: {email: 'c@c.com', 
        password: 'abc', 
        password_confirmation: 'abcd'},
        variant: 'phone')

    user = User.iphoners.last
    user.must_be_nil
  end
end