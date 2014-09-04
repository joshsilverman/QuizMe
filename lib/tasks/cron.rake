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
end

task :schedule_targeted_mentions => :environment do
  Asker.published.each { |asker| asker.schedule_targeted_mentions }
end

task :autofollow => :environment do
  start_date = Time.find_zone('UTC').parse('2013-05-17 9am').to_date
  Asker.published.sort_by { |a| a.followers.size }.slice(0, (Date.today - (start_date)).to_i).each { |a| a.autofollow() }
end
