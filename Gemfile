source 'https://rubygems.org'

gem "rspec-rails",'2.8.1', :group => [:test, :development]
gem 'pg'
ruby '2.0.0'

gem 'rails', '~> 4.0.0'
gem 'activesupport', '4.0.0'

group :test do
  gem 'capybara'
  gem 'minitest-rails-capybara'
  gem 'capybara_minitest_spec'
  gem 'launchy'
  gem 'factory_girl_rails'
  gem 'turn'#, :require => false
  gem "database_cleaner"
  gem 'timecop'
  gem 'm'
  gem 'selenium-webdriver'
  
  gem 'mocha'
  gem 'webmock'
  
  gem 'spork', '~> 1.0rc'
  gem "spork-minitest", "~> 0.0.3"
end

group :production do
  gem 'bcrypt-ruby', '3.0.1'
  gem 'dalli', '2.6.4'
  gem 'memcachier'
  gem 'rails_12factor'
  gem "non-stupid-digest-assets"
end

group :development do
  gem 'rack-mini-profiler'
  gem 'awesome_print'
  gem 'quiet_assets'
  gem 'better_errors'
  gem 'meta_request'
  gem 'awesome_print'
  gem 'heroku'

  # gem "guard"
  # gem "guard-livereload"
  # gem 'binding_of_caller'
  # gem 'oink'
  gem 'ruby-prof'
end

group :development, :test do
  gem 'pry'
end

gem 'sass-rails', '~> 4.0.0'
gem 'coffee-rails', '~> 4.0.0'
gem 'uglifier', '>= 2.1.1'
gem "less-rails"

gem 'jquery-ui-rails'
gem 'haml'
gem 'twitter-bootstrap-rails', '2.1.1'
gem 'jquery-rails'

gem 'devise'
gem 'omniauth'
gem 'omniauth-twitter'

gem 'rabl'
gem 'hirb'

gem 'twitter'
# gem 'tweetstream'

gem 'kaminari'
gem 'kaminari-bootstrap'
gem 'actionmailer', '~> 4.0.0'
gem 'newrelic_rpm'
gem 'mixpanel', '1.1.3'
gem 'sitemap_generator'
gem 'carrierwave'
gem 'fog'
gem 'roadie'
gem 'best_in_place', github: 'bernat/best_in_place'
gem 'mail'

gem 'stuff-classifier', :git => 'https://github.com/henghonglee/stuff-classifier' # no sqlite dependency #'git://github.com/alexandru/stuff-classifier.git'
gem 'split', :git => 'https://github.com/bderusha/split' #, :require => 'split/dashboard' #, :path => '~/Documents/RoR/gems/split'

gem 'amatch'
gem 'sourcify'
gem 'google_drive'
gem 'redis'

gem 'unicorn'
gem 'delayed_job_active_record', '~> 4.0.0.beta2'

gem 'd3_rails', '3.2.6.a'

gem 'protected_attributes'
gem 'rails-observers'
gem 'actionpack-page_caching'
gem 'actionpack-action_caching'
gem 'activerecord-deprecated_finders'

gem 'rails_12factor', group: :production