ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"
require "minitest"
require "minitest/rails"
require "minitest/autorun"
require "capybara/rails"
require 'database_cleaner'
require 'active_support/testing/setup_and_teardown'
require 'webmock/minitest'

class ActiveSupport::TestCase
  include Warden::Test::Helpers
  Warden.test_mode!

  include Capybara::DSL
  include Capybara::RSpecMatchers
  Capybara.default_wait_time = 5
  
  include FactoryGirl::Syntax::Methods
  include BestInPlace::TestHelpers

  include ActiveSupport::Testing::SetupAndTeardown
  include Rails.application.routes.url_helpers

  Rails.logger.level = 0

  self.use_transactional_fixtures = false
  self.use_instantiated_fixtures = false
  DatabaseCleaner.clean_with :truncation
  DatabaseCleaner.strategy = :transaction

  fixtures :all

  before :each do
    if !self.class.ancestors.include? ActionController::TestCase
      DatabaseCleaner.start 
    end

    Capybara.current_driver = :rack_test
    ActionMailer::Base.deliveries = []

    WebMock.disable_net_connect!(:allow => [/127\.0\.0\.1/, /twitter/])
    stub_request(:get, /mixpanel/)
    MP.stubs :track_event
    
    ActiveRecord::Base.observers.disable :all
  end

  after :each do
    Timecop.return

    if !self.class.ancestors.include? ActionController::TestCase
      DatabaseCleaner.clean
    end
  end
end

class ActionController::TestCase
  include Devise::TestHelpers

  before do
    # Capybara.reset_session!
    sign_out :user
  end

  after :each do
    DatabaseCleaner.clean_with :truncation
  end
end

require "mocha/setup"