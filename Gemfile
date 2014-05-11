source 'http://rubygems.org'
ruby '2.1.2'
gem 'puma'
gem 'rails', '4.1.1'
gem 'pg'
gem 'redis'

gem 'protected_attributes'
gem 'rails-observers'
gem 'actionpack-page_caching'
gem 'actionpack-action_caching'
gem 'activerecord-deprecated_finders'
gem "active_model_serializers"

gem 'delayed_job_active_record'

group :test do
  gem "rspec-rails",'2.8.1'
  gem 'capybara'
  gem 'capybara_minitest_spec', github: 'ordinaryzelig/capybara_minitest_spec'
  gem 'minitest-rails'

  gem 'factory_girl_rails'
  gem "database_cleaner"
  gem 'timecop'
  gem 'selenium-webdriver', "~> 2.38.0"
  gem 'mocha'
  gem 'webmock'
end

group :production do
  gem 'bcrypt-ruby', '3.0.1'
  gem 'dalli', '2.6.4'
  gem 'memcachier'
  gem 'rails_12factor'
  gem "non-stupid-digest-assets"
end

group :development do
  gem 'quiet_assets'
  gem 'ruby-prof'
  gem 'paleta'
end

group :development, :test do
  gem 'pry'
  gem 'pry-nav'
  gem "spring"
  gem "guard"
  gem "guard-minitest"
end

gem 'rails_admin', '0.6.2'

gem 'sass-rails', '~> 4.0.2'
gem 'coffee-rails', '~> 4.0.1'
gem 'uglifier', '>= 2.1.1'
gem "less-rails"

gem 'jquery-ui-rails'
gem 'haml'
gem 'twitter-bootstrap-rails'
gem 'therubyracer'
gem 'jquery-rails'
gem 'lodash-rails'
gem 'momentjs-rails'

gem 'devise', '3.0.4'
gem 'omniauth'
gem 'omniauth-twitter'
gem 'cancan'

gem 'oj'

gem 'twitter', '4.8.1'

gem 'kaminari'
gem 'kaminari-bootstrap'
gem 'actionmailer'
gem 'newrelic_rpm'
gem 'mixpanel', '1.1.3'
gem 'sitemap_generator'
gem 'carrierwave'
gem 'fog'
gem 'roadie'
gem 'best_in_place', github: 'bernat/best_in_place'
gem 'mail'

gem 'split', :git => 'https://github.com/bderusha/split' #, :require => 'split/dashboard' #, :path => '~/Documents/RoR/gems/split'

gem 'stuff-classifier', :git => 'https://github.com/henghonglee/stuff-classifier' # no sqlite dependency #'git://github.com/alexandru/stuff-classifier.git'
gem 'amatch'

gem 'sourcify', "~> 0.6.0.rc4"
gem 'pusher'