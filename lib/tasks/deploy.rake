task :deploy do
	system "git push origin master"
	test_suite_status = system "rake test"
	if test_suite_status
		system "git push wisr master"
		system "GEM_HOME='' BUNDLE_GEMFILE='' GEM_PATH='' RUBYOPT='' /usr/local/heroku/bin/heroku run rake db:migrate -a wisr"
		system "GEM_HOME='' BUNDLE_GEMFILE='' GEM_PATH='' RUBYOPT='' /usr/local/heroku/bin/heroku restart -a wisr"
	end
end