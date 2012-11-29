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
  askers = User.askers.where('twi_oauth_token is not null')
  puts "askers to post for:"
  puts askers.to_json
  askers.each do |a|
    next unless a.published
    puts "Posting question for #{a.twi_screen_name}"
    a.publish_question()
    sleep(8)
  end
end

task :fill_queue => :environment do
  User.askers.each do |asker|
    next unless asker.posts_per_day.present?
    PublicationQueue.clear_queue(asker)
    PublicationQueue.enqueue_questions(asker)
  end
end

task :save_stats => :environment do
  askers = User.askers.where('twi_oauth_token is not null')
  askers.each do |asker|
    Stat.update_stats_from_cache(asker)
    sleep(5)
  end
  Rails.cache.clear
end

# task :dm_new_followers => :environment do
#   askers = User.askers.where('twi_oauth_token is not null')
#   askers.each do |asker|
#     next if asker.new_user_q_id.nil?
#     Post.dm_new_followers(asker)  
#     sleep(2)  
#   end
# end

task :reengage_incorrect_answerers => :environment do
  User.reengage_incorrect_answerers()
end

task :reengage_inactive_users => :environment do
  User.reengage_inactive_users()
end

task :engage_new_users => :environment do 
  User.engage_new_users()
end

task :retweet_related => :environment do
  if Time.now.hour % 2 == 0
    ACCOUNT_DATA.each do |k, v|
      a = User.asker(k)
      pub = Publication.where(:asker_id => v[:retweet].sample, :published => true).order('updated_at DESC').limit(5).sample
      begin
        p = Post.find_by_publication_id_and_provider(pub.id, 'twitter')
        a.twitter.retweet(p.provider_post_id)
      rescue Exception => exception
        puts exception.message
        puts "exception while retweeting for #{a.twi_screen_name}"
      end
    end
  end
end

task :redis_garbage_collector => :environment do
  r = Split.redis
  if r.info['used_memory'].to_i > 15000000
    all_user_keys = r.keys('user_store:*')
    user_keys = []
    all_user_keys.each{|k| user_keys << k unless k=~/confirmed|finished/} #filter out any confirmed or finished keys
    user_keys.each do |k|
      r.del(k) unless r.get("#{k}:confirmed")
    end
  end
end
