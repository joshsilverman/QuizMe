require 'rubygems'

ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"
require "minitest/autorun"
require "minitest/rails"
require "capybara/rails"
require 'database_cleaner'
require "minitest/rails/capybara"
require 'active_support/testing/setup_and_teardown'
require 'webmock/minitest'

class MiniTest::Spec
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

  DatabaseCleaner.clean_with :truncation
  DatabaseCleaner.strategy = :transaction

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

  after :each do
    DatabaseCleaner.clean_with :truncation
  end
end

require "mocha/setup"