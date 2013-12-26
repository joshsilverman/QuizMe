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

  DatabaseCleaner.clean_with :truncation
  DatabaseCleaner.strategy = :truncation
  fixtures :all

  before :each do
    DatabaseCleaner.start
    Capybara.current_driver = :rack_test
    ActionMailer::Base.deliveries = []

    WebMock.disable_net_connect!(:allow => [/127\.0\.0\.1/, /twitter/])
    stub_request(:get, /mixpanel/)
    
    ActiveRecord::Base.observers.disable :all
  end

  after :each do
    Timecop.return
    DatabaseCleaner.clean
  end
end

class ActionController::TestCase
  include Devise::TestHelpers
end

class ActiveRecord::Base
  mattr_accessor :shared_connection
  @@shared_connection = nil

  def self.connection
    @@shared_connection || retrieve_connection
  end
end
ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection

require "mocha/setup"