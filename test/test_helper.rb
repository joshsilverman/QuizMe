ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"
require "minitest/autorun"
require "minitest/rails"
require "capybara/rails"
require 'database_cleaner'
require "minitest/rails/capybara"
require 'active_support/testing/setup_and_teardown'

DatabaseCleaner.strategy = :truncation
Rails.logger.level = 2

class ActiveSupport::TestCase
  include Warden::Test::Helpers
  Warden.test_mode!
  include Capybara::DSL
  include Capybara::RSpecMatchers
  include FactoryGirl::Syntax::Methods
  include BestInPlace::TestHelpers

  # controller test methods
  include ActiveSupport::Testing::SetupAndTeardown # for get/post/put/delete methods
  include Rails.application.routes.url_helpers

  self.use_transactional_fixtures = false
  self.use_instantiated_fixtures  = true
  fixtures :all

  Capybara.default_wait_time = 5

  before :each do
    DatabaseCleaner.clean
    Rails.cache.clear
    Timecop.return
    Capybara.current_driver = :rack_test
    ActionMailer::Base.deliveries = []
  end
end