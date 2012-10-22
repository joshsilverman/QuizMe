#lib/tasks/cron.rake
# require 'pusher'
# Pusher.app_id = '23912'
# Pusher.key = 'bffe5352760b25f9b8bd'
# Pusher.secret = '782e6b3a20d17f5896dc'

task :check_for_posts => :environment do
	askers = User.askers.where('twi_oauth_token is not null')
	askers.each do |a|
		Post.check_for_posts(a)
		sleep(3)
	end
end

task :post_question => :environment do
	# t = Time.now
	askers = User.askers.where('twi_oauth_token is not null')
	puts "askers to post for:"
	puts askers.to_json
	askers.each do |a|
		puts "Posting question for #{a.twi_screen_name}"
		a.publish_question()
		sleep(5)
	end
	# User.askers.each do |asker|
	# 	# shift = (t.hour/a.posts_per_day.to_f).floor + 1
	# 	# queue_index = t.hour%a.posts_per_day
	# 	# Question.post_question(a, queue_index, shift)
	# 	asker.publish_question()
	# 	sleep(10)
	# end
end

task :fill_queue => :environment do
	User.askers.each do |asker|
		PublicationQueue.clear_queue(asker)
		PublicationQueue.enqueue_questions(asker)
	end
end

task :save_stats => :environment do
	askers = User.askers.where('twi_oauth_token is not null')
	askers.each do |asker|
		Stat.update_stats_from_cache(asker)
		sleep(10)
	end
	Rails.cache.clear
end

task :dm_new_followers => :environment do
	askers = User.askers.where('twi_oauth_token is not null')
	askers.each do |asker|
		next if asker.new_user_q_id.nil?
		Post.dm_new_followers(asker)		
	end

end

task :reengage_users => :environment do
	asker_ids = User.askers.collect(&:id)
	current_time = Time.now
	64.times do |i|
		current_time += 1.hour
		puts current_time

		# hours_ago = 22.hours.ago
		hours_ago = current_time - 23.hours
		if (current_time.hour % 3 == 0)
			Post.create(:correct => false, :created_at => current_time, :user_id => 3, :in_reply_to_user_id => 2, :interaction_type => 2) 
			puts "created new post"
		end
		puts "range = - #{(hours_ago - 1.day)} - #{hours_ago}"
		recent_posts = Post.where("user_id is not null and ((correct = ? and created_at > ? and created_at < ? and interaction_type = 2) or (intention = ? and created_at > ?))", false, (hours_ago - 1.day), hours_ago, 'reengage', hours_ago)
		user_grouped_posts = recent_posts.group_by(&:user_id)
		user_grouped_posts.each do |user_id, posts|
			# puts user_id, posts.to_json
			next if asker_ids.include? user_id or recent_posts.where(:intention => 'reengage', :in_reply_to_user_id => user_id).present?
			incorrect_post = posts.sample
			post = Post.create(:intention => "reengage", :created_at => current_time, :user_id => incorrect_post.in_reply_to_user_id, :in_reply_to_user_id => user_id)
			puts "sending reengage message to: #{user_id}"
		end
		puts "\n\n"
	end
end

task :retweet_related => :environment do
	if Time.now.hour % 2 == 0
		ACCOUNT_DATA.each do |k, v|
			a = User.asker(k)
			pub = Publication.where(:asker_id => v[:retweet].sample, :published => true).order('updated_at DESC').limit(5).sample
			p = Post.find_by_publication_id_and_provider(pub.id, 'twitter')
			begin
				a.twitter.retweet(p.provider_post_id)
			rescue Exception => exception
				puts exception.message
				puts "exception while retweeting #{p.text} (id: #{p.id}):"
			end
		end
	end
end