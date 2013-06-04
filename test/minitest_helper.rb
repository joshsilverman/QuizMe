ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "minitest/autorun"
require "minitest/rails"
require "capybara/rails"
require 'database_cleaner'
require "minitest/rails/capybara"

DatabaseCleaner.strategy = :truncation

class ControllerTest < MiniTest::Spec
  include Rails.application.routes.url_helpers
  register_spec_type(/controller/, self)
end

class ActiveSupport::TestCase
  include Warden::Test::Helpers
  Warden.test_mode!
  include Capybara::DSL
  include Capybara::RSpecMatchers

  self.use_transactional_fixtures = false
  self.use_instantiated_fixtures  = true
  fixtures :all

  before :each do
    DatabaseCleaner.clean
    Rails.cache.clear
    Timecop.return
    Capybara.current_driver = :rack_test
  end
end