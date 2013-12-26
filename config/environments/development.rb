$stdout.sync = true
Quizmemanager::Application.configure do
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

Pusher.app_id = '62265'
Pusher.key    = 'f10076f83cadd6eb2b0d'
Pusher.secret = 'cb6ea075a82c13cb4986'