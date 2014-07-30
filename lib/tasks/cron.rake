#lib/tasks/cron.rake

task :check_for_posts => :environment do
  selector = (((Time.now - Time.now.beginning_of_hour) / 60) / 10).round % 2
  Asker.published.select { |a| a.id % 2 != selector }.each do |a|
    Post.delay.check_for_posts(a)
  end
end

task :collect_retweets => :environment do
  Asker.published.each do |a|
    Post.collect_retweets(a)
    sleep 1
  end
end

task :post_question => :environment do
  Asker.published.each do |asker|
    if asker.posts_per_day > 5
      interval = 1
    elsif asker.posts_per_day > 4
      interval = 2
    else
      interval = 3
    end
    next unless (Time.now.hour % interval == 0)
    
    asker.publish_question()
    sleep 6
  end
  Rails.cache.delete 'publications_recent'
end

task :fill_queue => :environment do
  Asker.published.each do |asker|
    next unless asker.posts_per_day.present?
    PublicationQueue.clear_queue(asker)
    PublicationQueue.enqueue_questions(asker)
  end
end

task :reengage_inactive_users => :environment do
  Asker.reengage_inactive_users()
  # Asker.send_author_followups()
  Asker.send_nudge_followups()
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

task :unfollow_inactive_users => :environment do
  Asker.published.each { |asker| asker.unfollow_oldest_inactive_user() }
end

task :send_progress_reports => :environment do
  Asker.send_progress_reports() if Time.now.wday == 0
end

task :retweet_related => :environment do
  if Time.now.hour % 2 == 0
    Asker.retweet_related()
  end
  if Time.now.hour % 9 == 0 and UNDER_CONSTRUCTION_HANDLES.present?
    UNDER_CONSTRUCTION_HANDLES.each do |new_handle_id|
      new_asker = Asker.find(new_handle_id)
      questions_remaining = (30 - new_asker.questions.size)
      if questions_remaining > 0
        ACCOUNT_DATA[new_handle_id][:retweet].each do |asker_id|
          a = Asker.find(asker_id)
          a.send_public_message("We need #{questions_remaining} more questions to launch #{new_asker.twi_screen_name}! Help by writing one here: wisr.com/feeds/#{new_handle_id}?q=1", {
            :intention => 'solicit ugc',
            :interaction_type => 2
          })
        end
      else
        puts "Enough questions for #{new_asker.twi_screen_name}!"
      end
    end
  end      
end

task :schedule_targeted_mentions => :environment do
  Asker.published.each { |asker| asker.schedule_targeted_mentions }
end

task :autofollow => :environment do
  start_date = Time.find_zone('UTC').parse('2013-05-17 9am').to_date
  Asker.published.sort_by { |a| a.followers.size }.slice(0, (Date.today - (start_date)).to_i).each { |a| a.autofollow() }
end