ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "minitest/autorun"
require "minitest/rails"
require "capybara/rails"
require 'database_cleaner'
require "minitest/pride"
ADMINS = []

class IntegrationTest < MiniTest::Spec
  include Rails.application.routes.url_helpers
  include Capybara::DSL
  register_spec_type(/integration$/, self)
end

DatabaseCleaner.strategy = :truncation

class ActiveSupport::TestCase
  include Warden::Test::Helpers
  Warden.test_mode!
  include Capybara::DSL

  before :each do
    DatabaseCleaner.clean
    Rails.cache.clear
    Timecop.return
  end
end