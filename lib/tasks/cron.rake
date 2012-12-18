#lib/tasks/cron.rake
# require 'pusher'
# Pusher.app_id = '23912'
# Pusher.key = 'bffe5352760b25f9b8bd'
# Pusher.secret = '782e6b3a20d17f5896dc'

task :check_for_posts => :environment do
  askers = Asker.where('twi_oauth_token is not null')
  askers.each do |a|
    Post.check_for_posts(a)
    sleep(3)
  end
end

task :post_question => :environment do
  askers = Asker.where('twi_oauth_token is not null')
  askers.each do |a|
    next unless a.published
    puts "Posting question for #{a.twi_screen_name}"
    a.publish_question()
    sleep(8)
  end
end

task :fill_queue => :environment do
  Asker.all.each do |asker|
    next unless asker.posts_per_day.present?
    PublicationQueue.clear_queue(asker)
    PublicationQueue.enqueue_questions(asker)
  end
end

task :save_stats => :environment do
  askers = Asker.where('twi_oauth_token is not null')
  askers.each do |asker|
    Stat.update_stats_from_cache(asker)
    Rails.cache.delete("stats:#{asker.id}")
    sleep(5)
  end
end

task :reengage_incorrect_answerers => :environment do
  Asker.reengage_incorrect_answerers()
end

task :reengage_inactive_users => :environment do
  Asker.reengage_inactive_users()
end

task :engage_new_users => :environment do 
  Asker.engage_new_users()
end

task :post_aggregate_activity => :environment do 
  Asker.post_aggregate_activity()
end

# task :update_followers => :environment do
  # Asker.all.each { |asker| asker.update_followers() }
# end

task :retweet_related => :environment do
  if Time.now.hour % 2 == 0
    ACCOUNT_DATA.each do |k, v|
      a = Asker.find(k)
      pub = Publication.where(:asker_id => v[:retweet].sample, :published => true).order('updated_at DESC').limit(5).sample
      begin
        p = Post.find_by_publication_id_and_provider(pub.id, 'twitter')
        a.twitter.retweet(p.provider_post_id)
      rescue Exception => exception
        puts exception.message
        puts "exception while retweeting for #{a.twi_screen_name}"
      end
      if Time.now.hour % 11 == 0
        Post.tweet(a, "Want me to publish YOUR questions? Click the link: wisr.com/feeds/#{a.id}?q=1", {
          :intention => 'solicit ugc',
          :interaction_type => 2
        })
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
