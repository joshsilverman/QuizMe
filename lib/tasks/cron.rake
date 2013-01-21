#lib/tasks/cron.rake

task :check_for_posts => :environment do
  askers = Asker.where('twi_oauth_token is not null')
  askers.each do |a|
    Post.check_for_posts(a)
    sleep(3)
  end
end

task :post_question => :environment do
  Asker.where('twi_oauth_token is not null and published = ?', true).each do |a|
    puts "Posting question for #{a.twi_screen_name}"
    a.publish_question()
    sleep(3)
  end
end

task :fill_queue => :environment do
  Asker.all.each do |asker|
    next unless asker.posts_per_day.present?
    PublicationQueue.clear_queue(asker)
    PublicationQueue.enqueue_questions(asker)
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

task :segment_users => :environment do
  User.update_segments()
end

task :send_weekly_progress_dms => :environment do
  Asker.send_weekly_progress_dms() if Time.now.wday == 7
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

task :email_supporters => :environment do
  drive = GoogleDrive.login("jsilverman@studyegg.com", "GlJnb@n@n@")
  spreadsheet = drive.spreadsheet_by_key("0AliLeS3-noSidGJESjZoZy11bHo2ekNQS2I5TGN6eWc").worksheet_by_title('Sheet1')
  last_row_index = spreadsheet.num_rows - 2
  list = spreadsheet.list
  jason = [list.get(last_row_index, 'Jason Serendipity'), list.get(last_row_index - 1, 'Jason Serendipity')].reject { |t| t.blank? }.first
  josh = [list.get(last_row_index, 'Josh Serendipity'), list.get(last_row_index - 1, 'Josh Serendipity')].reject { |t| t.blank? }.first
  
  User.supporters.each do |user|
    UserMailer.newsletter(user, jason, josh).deliver
  end
end
