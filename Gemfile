source :rubygems

gem "rspec-rails",'2.8.1', :group => [:test, :development]
gem 'pg', '0.14.0'#, :require => false

group :test do
  gem 'minitest'
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'turn', :require => false
  gem "database_cleaner"
  gem 'timecop'
end

group :production do
  gem 'bcrypt-ruby', '3.0.1'
  gem 'dalli', '2.1.0'
end

group :development do
  gem 'rack-mini-profiler'
  gem 'awesome_print'
  gem 'quiet_assets'
  gem 'heroku'
  gem 'better_errors'
  gem 'meta_request'

  # gem "guard"
  # gem "guard-livereload"
  # gem 'binding_of_caller'
  # gem 'oink'
  # gem 'ruby-prof'
end

group :assets do
  gem 'sass-rails', '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '1.2.6'
  gem 'therubyracer', '0.10.1'
end

gem 'rails', '3.2.11'
gem 'jquery-ui-rails'
gem 'haml', '3.1.6'
gem 'twitter-bootstrap-rails', '2.1.1'
gem 'jquery-rails', '1.0.19'

gem 'devise'
gem 'omniauth'
gem 'omniauth-twitter'

gem 'rabl', '0.6.14'
gem 'hirb'

gem 'twitter', '4.5.0'
# gem 'tweetstream'

gem 'kaminari'
gem 'kaminari-bootstrap'
gem 'roadie'
gem 'newrelic_rpm'
gem 'mixpanel', '1.1.3'
gem 'sitemap_generator'
gem 'best_in_place'

gem 'bitly', :git => 'https://github.com/KentonWhite/bitly.git'
gem 'stuff-classifier', :git => 'https://github.com/henghonglee/stuff-classifier' # no sqlite dependency #'git://github.com/alexandru/stuff-classifier.git'
gem 'split', :git => 'https://github.com/bderusha/split' #, :require => 'split/dashboard' #, :path => '~/Documents/RoR/gems/split'

gem 'amatch'
gem 'sourcify'
gem 'google_drive'
gem 'redis'

gem 'delayed_job_active_record'
