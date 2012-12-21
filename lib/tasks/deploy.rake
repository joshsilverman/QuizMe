task :deploy do
	system "git push wisr master"
	system "heroku run rake db:migrate -a wisr"
	system "heroku run ruby ./script/stream.rb -a wisr"
end