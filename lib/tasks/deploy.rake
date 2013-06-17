task :deploy do
	system "rake test"
	system "git push wisr master"
	system "GEM_HOME='' BUNDLE_GEMFILE='' GEM_PATH='' RUBYOPT='' /usr/local/heroku/bin/heroku run rake db:migrate -a wisr"
	system "GEM_HOME='' BUNDLE_GEMFILE='' GEM_PATH='' RUBYOPT='' /usr/local/heroku/bin/heroku restart -a wisr"
	
	# system "GEM_HOME='' BUNDLE_GEMFILE='' GEM_PATH='' RUBYOPT='' /usr/local/heroku/bin/heroku run `nohup ruby ./script/stream.rb &` -a wisr"
end