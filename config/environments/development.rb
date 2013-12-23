$stdout.sync = true
Quizmemanager::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb
  
  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  config.eager_load = false

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Don't care if the mailer can't send
  config.action_mailer.delivery_method = :test
  # config.action_mailer.default_url_options = { :host => 'localhost:5000' }
  # config.action_mailer.raise_delivery_errors = true
  # config.action_mailer.delivery_method = :smtp
  # ENV['SENDGRID_PASSWORD'] = 'zseli3ne'
  # ENV['SENDGRID_USERNAME'] = 'app6915090@heroku.com'

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Expands the lines which load the assets
  config.assets.debug = true

  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger.const_get(
    ENV['LOG_LEVEL'] ? ENV['LOG_LEVEL'].upcase : 'DEBUG'
  )  
end

Pusher.app_id = '62264'
Pusher.key    = '95a6d252b4fb7089dd2a'
Pusher.secret = 'ed3d0f22ffc0669b3a8d'