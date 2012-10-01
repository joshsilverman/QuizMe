source :rubygems

gem "rspec-rails", :group => [:test, :development]
# gem 'rack-mini-profiler' #won't show up in production

group :test do
  gem 'sqlite3'
  gem 'turn', :require => false
  gem "database_cleaner"
end

group :production do
  gem 'pg', :require => false
  gem 'bcrypt-ruby'
end

group :development do
  # gem "guard"
  # gem "guard-livereload"
end

group :assets do
  gem 'sass-rails'
  gem 'coffee-rails'
  gem 'uglifier'
  gem 'therubyracer'
end

gem 'haml'
gem 'devise'
gem 'rails', '3.1.3'
gem 'twitter-bootstrap-rails'
gem 'jquery-rails'
gem 'omniauth'
gem 'omniauth-oauth2'
gem 'omniauth-twitter'
gem 'omniauth-facebook'
gem 'omniauth-tumblr'
gem 'rabl'
gem 'dalli'
gem 'hirb'
gem 'twitter'
gem 'tumblife'
gem 'url_shortener'
gem 'pusher'
gem 'newrelic_rpm'
gem 'mixpanel_client', :git => 'git://github.com/bderusha/mixpanel_client.git'

gem 'best_in_place'