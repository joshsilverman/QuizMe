task :deploy do
	system "git push wisr master"
	system "GEM_HOME='' BUNDLE_GEMFILE='' GEM_PATH='' RUBYOPT='' /usr/local/heroku/bin/heroku run rake db:migrate -a wisr"
	# system "GEM_HOME='' BUNDLE_GEMFILE='' GEM_PATH='' RUBYOPT='' /usr/local/heroku/bin/heroku run `nohup ruby ./script/stream.rb &` -a wisr"
end