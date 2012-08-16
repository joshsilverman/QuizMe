#lib/tasks/cron.rake
require 'pusher'
Pusher.app_id = '23912'
Pusher.key = 'bffe5352760b25f9b8bd'
Pusher.secret = '782e6b3a20d17f5896dc'

task :check_mentions => :environment do
	askers = User.askers.where('twi_oauth_token is not null')
	askers.each do |a|
		Engagement.check_for_engagements(a)
		sleep(10)
	end
end

task :post_question => :environment do
	t = Time.now
	askers = User.askers
	askers.each do |a|
		shift = (t.hour/a.posts_per_day.to_f).floor + 1
		queue_index = t.hour%a.posts_per_day
		Question.post_question(a, queue_index, shift)
		sleep(10)
	end
end

task :fill_queue => :environment do
	PostQueue.clear_queue
	askers = User.askers
	askers.each do |a|
		Question.select_questions_to_post(a, 7)
	end
end

task :save_stats => :environment do
	askers = User.askers.where('twi_oauth_token is not null')
	askers.each do |a|
		Stat.save_daily_stats_for_account(a)
		sleep(10)
	end
end

task :dm_new_followers => :environment do
	# asker = User.asker(4)
	# Post.dm_new_followers(asker)
	puts "TODO: add default dm post for all askers"
end

task :post_leaderboard => :environment do
	puts "TODO: turn on post leaderboard for all askers"
	# account = Account.find(2)
	# data = Account.get_top_scorers(account.id)
	# #data = {:name=>"QuizMeBio", :scores=>[{:handle=>"Anwar_shabab", :correct=>119}, {:handle=>"SHRUSHTIKHERADK", :correct=>84}, {:handle=>"princessFeeBee", :correct=>77}, {:handle=>"BrianMendel", :correct=>58}, {:handle=>"Josephunleashed", :correct=>54}, {:handle=>"melissariks", :correct=>52}, {:handle=>"tdownham_mi", :correct=>45}, {:handle=>"karinehage", :correct=>39}, {:handle=>"MyriamLt2", :correct=>32}, {:handle=>"thecancergeek", :correct=>31}]}
	# top5 = ''
	# bottom5 = ''
	# data[:scores].each_with_index do |s, i|
	# 	if i < 5
	# 		top5 += "@#{s[:handle]} "
	# 	else
	# 		bottom5 += "@#{s[:handle]} "
	# 	end
	# end
	# tweet1 = "The leaderboard is out! Look who's on top! http://bit.ly/QckFN6 #{top5}"
	# tweet2 = "Check out the leaderboard and keep up with the top scorers! http://bit.ly/QckFN6 #{bottom5}"

	# puts "#{tweet1} #{tweet1.length}"
	# puts "#{tweet2} #{tweet2.length}"
	# Post.tweet(account, tweet1, nil, nil, nil)
	# sleep(10)
	# Post.tweet(account, tweet2, nil, nil, nil)
end