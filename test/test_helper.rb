ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"
require "minitest/autorun"
require "minitest/rails"
require "capybara/rails"
require 'database_cleaner'
require "minitest/rails/capybara"

DatabaseCleaner.strategy = :truncation
Rails.logger.level = 2

class ControllerTest < MiniTest::Spec
  include Rails.application.routes.url_helpers
  register_spec_type(/controller/, self)
end

class ActiveSupport::TestCase
  include Warden::Test::Helpers
  Warden.test_mode!
  include Capybara::DSL
  include Capybara::RSpecMatchers
  include FactoryGirl::Syntax::Methods
  include BestInPlace::TestHelpers

  self.use_transactional_fixtures = false
  self.use_instantiated_fixtures  = true
  fixtures :all

  before :each do
    DatabaseCleaner.clean
    Rails.cache.clear
    Timecop.return
    Capybara.current_driver = :rack_test
    ActionMailer::Base.deliveries = []
  end
end