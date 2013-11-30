require 'rubygems'
require 'spork'

Spork.prefork do
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
    self.use_instantiated_fixtures  = false
    fixtures :all

    Capybara.default_wait_time = 5

    before :each do
      DatabaseCleaner.clean
      Rails.cache.clear
      Timecop.return
      Capybara.current_driver = :rack_test
      ActionMailer::Base.deliveries = []

      # default mock settings
      WebMock.disable_net_connect!(:allow => [/127\.0\.0\.1/, /twitter/])
      stub_request(:get, /mixpanel/)
      
      # disable all observers
      ActiveRecord::Base.observers.disable :all
    end

    after :each do
      Timecop.return
    end
  end

  require "mocha/setup"

end

Spork.each_run do
end