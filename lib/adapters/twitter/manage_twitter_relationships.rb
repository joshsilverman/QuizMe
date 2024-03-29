module ManageTwitterRelationships
  
  ## Autofollows
  def autofollow options = {}
    puts "in autofollow for #{twi_screen_name}"
    # Check if we should follow
    return unless (max_follows = autofollow_count) > 0

    # Twi search to get follow targets
    if options[:twi_user_ids]
      twi_user_ids = options[:twi_user_ids]
      search_term_source = {}
    else
      twi_users, search_term_source = get_follow_target_twi_users(max_follows)
      twi_user_ids = twi_users.collect(&:id)
    end
    
    # Send follow requests
    self.delay.send_autofollows(twi_user_ids, max_follows, { force: options[:force], search_term_source: search_term_source })
  end

  def autofollow_count max_follows = nil
    target_follow_count_avg = (followers.count / 150).floor + 1 # number of follows per day to shoot for
    target_follow_count_avg = 5 if target_follow_count_avg > 5
    scale = [0.0, 0.0, 1.6, 1.0, 1.8, 0.7, 1.9][((id + Time.now.wday + Time.now.to_date.cweek) % 7)] # pick a scale val for today
    max_follows = (target_follow_count_avg * scale).round # scale target avg
    # Check if we should follow today
    # max_follows ||= [0, 0, 9, 4, 12, 2, 11][((id + Time.now.wday + Time.now.to_date.cweek) % 7)]

    return 0 if max_follows == 0
    # Check if we should follow during this part of the day
    return 0 if Time.now.hour <= ((id + Time.now.wday + Time.now.to_date.cweek) % 6)
    return 0 if Time.now.hour > ((id + Time.now.wday + Time.now.to_date.cweek) % 6 + 18)
    # Check if we've already followed enough users today
    
    follows_count_today = follow_relationships.twitter
      .where("created_at > ?", Time.now.beginning_of_day)
      .where("type_id is null or type_id = ?", 2).count
    max_follows = max_follows - follows_count_today
    return 0 if max_follows < 1

    return max_follows
  end

  def get_follow_target_twi_users max_follows
    follow_target_twi_users = []
    search_term_source = {}
    wisr_follows_ids = follows_with_inactive.collect(&:twi_user_id)
    search_terms.shuffle.each do |search_term|
      next if follow_target_twi_users.size >= max_follows
      statuses = Post.twitter_request { twitter.search(search_term.name, :count => 100).statuses }
      next unless statuses.present?
      twi_users = statuses.select { |s| s.user.present? }.collect { |s| s.user }.uniq
      twi_users.reject! { |twi_user| wisr_follows_ids.include?(twi_user.id) or follow_target_twi_users.include?(twi_user.id) }
      twi_users.sample(max_follows - follow_target_twi_users.size).each do |twi_user|
        follow_target_twi_users << twi_user
        search_term_source[twi_user.id] = search_term
      end
    end
    puts "Too few autofollows found for #{twi_screen_name} (only found #{follow_target_twi_users.size})!" if follow_target_twi_users.size < max_follows
    return follow_target_twi_users, search_term_source
  end

  def send_autofollows twi_user_ids, max_follows, options = {}
    twi_user_ids.sample(max_follows).each do |twi_user_id|
      response = Post.twitter_request { twitter.follow(twi_user_id) }

      if response.present? or options[:force]
        user = User.find_or_initialize_by(twi_user_id: (twi_user_id))
        user.save!
        if options[:search_term_source] and search_term = options[:search_term_source][twi_user_id]
          user.update_attribute(:search_term_topic_id, search_term.id)
        end
        add_follow(user, 2)
      else
        puts "Twitter Error: Could not autofollow user #{twi_user_id} from #{id}"
      end 
      sleep((1..3).to_a.sample) unless options[:force] # avoids sleep in tests
    end
  end

  ## Update relationships
  def update_relationships
    puts "in update_relationships for #{twi_screen_name}"
    twi_follows_ids = request_and_update_follows
    twi_follower_ids = request_and_update_followers

    followback(twi_follower_ids) unless twi_follower_ids.blank?
    
    if twi_follows_ids.present? and (max_unfollows = unfollow_count) > 0
      unfollow_nonreciprocal(twi_follows_ids, max_unfollows)
    end
  end

  def unfollow_count max_unfollows = nil
    target_unfollow_count_avg = (followers.count / 150).floor + 3 # number of follows per day to shoot for
    target_unfollow_count_avg = 7 if target_unfollow_count_avg > 7
    scale = [0.0, 0.0, 1.6, 2.0, 0.4, 1.2, 1.8][((id + Time.now.wday + Time.now.to_date.cweek) % 7)] # pick a scale val for today
    max_unfollows = (target_unfollow_count_avg * scale).round # scale target avg

    # Check if we should unfollow today
    # max_unfollows ||= [0, 0, 8, 10, 2, 6, 9][((id + Time.now.wday + Time.now.to_date.cweek) % 7)]
    return 0 if max_unfollows == 0
    
    # Check if we should unfollow during this part of the day
    return 0 if Time.now.hour <= ((id + Time.now.wday + Time.now.to_date.cweek) % 6)
    return 0 if Time.now.hour > ((id + Time.now.wday + Time.now.to_date.cweek) % 6 + 18)
    
    # Check if we've already unfollowed enough users today
    unfollows_count_today = follow_relationships.inactive\
      .where("updated_at > ?", Time.now.beginning_of_day)\
      .where("created_at < ?", Time.now.beginning_of_day)\
      .where("type_id is null or type_id != 4").count
    max_unfollows = max_unfollows - unfollows_count_today
    return 0 if max_unfollows < 1

    max_unfollows
  end

  def request_and_update_follows
    twi_follows_ids = Post.twitter_request { twitter.friend_ids.ids }
    update_follows(twi_follows_ids, follows.collect(&:twi_user_id)) if twi_follows_ids.present?
  end

  def update_follows twi_follows_ids, wisr_follows_ids
    # Add new friends in wisr
    (twi_follows_ids - wisr_follows_ids).each do |new_user_twi_id| 
      add_follow(User.find_or_create_by(twi_user_id: (new_user_twi_id))) # Should have a type_id?     
    end

    # Remove unfollows from asker follow association
    removeable_ids = wisr_follows_ids - twi_follows_ids    
    User.where("twi_user_id in (?)", removeable_ids).each do |unfollowed_user| 
      remove_follow(unfollowed_user)
    end
    
    twi_follows_ids 
  end

  def unfollow_nonreciprocal twi_follows_ids, max_unfollows, limit = 30.days.ago
    nonreciprocal_followers = User
      .where(twi_user_id: (twi_follows_ids - followers.collect(&:twi_user_id)))
    nonreciprocal_follower_ids = nonreciprocal_followers.collect(&:id)
    nonreciprocal_follower_ids = [0] if nonreciprocal_follower_ids.empty?
    follow_relationships.active
      .where('updated_at < ? AND followed_id IN (?)', limit, nonreciprocal_follower_ids)
      .sample(max_unfollows).each do |nonreciprocal_relationship|

      user = nonreciprocal_followers.select { |u| 
        u.id == nonreciprocal_relationship.followed_id }.first
      response = Post.twitter_request { twitter.unfollow(user.twi_user_id) }
      if response.present?
        remove_follow(user)
        puts "Unfollowed user #{user.twi_user_id} from #{id}"
      else
        puts "Twitter Error: Could not unfollow user #{user.twi_user_id} from #{id}"
      end
    end
  end 

  def unfollow_oldest_inactive_user limit = 90.days.ago
    oldest_inactive_user = follows.includes(:posts)
      .where("users.created_at < ? and posts.user_id is null", limit)
      .references(:posts)
      .order("users.created_at ASC")
      .limit(1).first
    
    if oldest_inactive_user
      Post.twitter_request { twitter.unfollow(oldest_inactive_user.twi_user_id) }
      remove_follow(oldest_inactive_user)
    else
      puts 'Twitter Error: no oldest_inactive_user to unfollow'
    end
  end 

  def add_follow user, type_id = nil, channel = Relationship::TWITTER
    relationship = follow_relationships
      .find_or_initialize_by(followed_id: user.id)
    relationship.update_attributes(
      active: true, 
      type_id: type_id, 
      pending: false,
      channel: channel)
    MP.track_event "add follow", { distinct_id: id, type_id: type_id }  
  end

  def remove_follow user
    relationship = follow_relationships.find_by(followed_id: user.id)
    if relationship
      relationship.update_attribute(:active, false) 
      MP.track_event "remove follow", { distinct_id: id }
    end
  end  

  def request_and_update_followers
    twi_follower_ids = Post.twitter_request { twitter.follower_ids.ids }
    if twi_follower_ids.present?
      update_followers(twi_follower_ids, followers.collect(&:twi_user_id))
    end
  end

  def update_followers twi_follower_ids, wisr_follower_ids
    # Add new followers in wisr
    asker_follows = follows
    (twi_follower_ids - wisr_follower_ids).each do |new_user_twi_id|
      follower = User.find_or_create_by(twi_user_id: new_user_twi_id)
      follower_type_id = asker_follows.include?(follower) ? 1 : 3
      add_follower(follower, follower_type_id)
    end

    # Remove unfollowers from asker follow association
    not_following_over_twitter_ids = wisr_follower_ids - twi_follower_ids

    following_over_wisr_channel_ids = Relationship.wisr
      .where(followed_id: id).pluck(:follower_id)
    following_over_wisr_twitter_ids = User
      .where('id IN (?)', following_over_wisr_channel_ids).pluck(:twi_user_id)

    removeable_ids = not_following_over_twitter_ids - following_over_wisr_twitter_ids
    User.where("twi_user_id in (?)", removeable_ids).each do |unfollowed_user| 
      remove_follower(unfollowed_user)
    end

    twi_follower_ids 
  end 

  def followback twi_follower_ids
    return if follow_relationships.search.where("created_at > ?", Time.now.beginning_of_day).size >= 20
    
    twi_pending_ids = Post.twitter_request { twitter.friendships_outgoing.ids }
    i = 0

    twi_ids_to_followback = (twi_follower_ids - follows.collect(&:twi_user_id))
    existing_users_ids_twi_user_ids = User.where("twi_user_id in (?)", twi_ids_to_followback).pluck(:id, :twi_user_id)
    existing_users_ids = existing_users_ids_twi_user_ids.map {|el| el[0]}
    asker_follow_relationships = follow_relationships
      .where("followed_id in (?)", existing_users_ids)
      .group_by(&:followed_id)

    twi_ids_to_followback.each do |twi_user_id| # should be doing the following instead, tests need to be updated: (followers - follows).each do |user|
      ## THIS IS THE SOURCE OF THE EXCESSIVE USER LOADS
      user_id_pair = existing_users_ids_twi_user_ids.select { |el| el[1] == twi_user_id }[0]
      if (user_id_pair)
        user_id = user_id_pair[0]
      else
        user_id = User.find_or_create_by(twi_user_id: twi_user_id).pluck :id
      end

      # user = User.where(id: user_id).first

      if asker_follow_relationships[user_id] and asker_follow_relationships[user_id].select { |r| r.pending == true }.present? # Skip followback again -- request pending
        next
      elsif twi_pending_ids.include? twi_user_id # Skip followback -- request pending
        follow_relationships.find_or_initialize_by(followed_id: user_id)
          .update(pending: true,
            channel: Relationship::TWITTER)
        next
      elsif asker_follow_relationships[user_id] and asker_follow_relationships[user_id].select { |r| r.type_id == 4 }.present? # Skip followback -- account was suspended (?)
        next
      elsif asker_follow_relationships[user_id] and asker_follow_relationships[user_id].select { |r| r.active == false }.present? # Skip followback -- user was inactive unfollowed
        next
      end

      if i >= 1 # Too many followbacks (1) to run all now
        return
      end
      i += 1

      response = Post.twitter_request { twitter.follow(twi_user_id) }
      if response.nil? # possible suspended acct, setting relationship to suspended
        puts "Twitter Error: Could not follow (suspended?) user #{twi_user_id} from #{id}"
        follow_relationships.find_or_initialize_by(followed_id: user_id)
          .update_attributes(
            type_id: 4, 
            active: false,
            channel: Relationship::TWITTER) 
        next
      elsif response.empty?
        puts "Twitter Error: Could not followback user #{twi_user_id} from #{id}"
        update(last_followback_failure: Time.now)
        next
      end
      
      user = User.find(user_id)
      add_follow(user, 1)
    end
  end

  def add_follower user, type_id = nil, channel = Relationship::TWITTER
    relationship = follower_relationships.find_or_initialize_by(follower_id: user.id)
    relationship.update(
      active: true, 
      type_id: type_id, 
      pending: false,
      channel: Relationship::TWITTER)
    send_new_user_question(user)
    user.segment
  end

  def remove_follower user
    relationship = follower_relationships.find_by(follower_id: user.id)
    relationship.update_attribute :active, false if relationship
    user.segment
  end

  ## Targeted mentions
  def schedule_targeted_mentions options = {}
    target_count = targeted_mention_count
    return false if target_count < 1

    if options[:target_users].present? # for tests
      target_users = options[:target_users].sample(target_count)
    else
      return false if search_terms.blank?
      target_users, search_term_source = get_targeted_mention_twi_user_targets(target_count)
    end

    interval = (24 / target_users.size.to_f)
    target_users.each_with_index do |target_user, i|
      if options[:target_users]
        user = target_user
      else
        user = User.find_or_initialize_by(twi_user_id: target_user.id)
        user.update(
          twi_name: target_user.name,
          name: target_user.name,
          twi_screen_name: target_user.screen_name,
          description: target_user.description.present? ? target_user.description : nil,
          search_term_topic_id: search_term_source[target_user.id].try(:id)
        )
      end
      Delayed::Job.enqueue(
        TargetedMention.new(self, user),
        :run_at => (Time.now + (interval * i).hours)
      )    
    end
  end

  def send_targeted_mention user
    question = most_popular_question
    return unless question

    publication = question.publications.published.order("created_at DESC").first
    return unless publication

    self.send_public_message(question.text, { 
      reply_to: user.twi_screen_name, 
      intention: 'targeted mention', 
      question_id: question.id,
      in_reply_to_user_id: user.id,
      publication_id: publication.id,
      long_url: "#{URL}/#{subject_url}/#{publication.id}", 
      interaction_type: 2
    })
    MP.track_event "targeted mention sent", { distinct_id: user.id, asker: twi_screen_name }
  end

  def targeted_mention_count
    follower_count = followers.count
    if follower_count > 3000
      count = 8
    elsif follower_count > 2000
      count = 7
    elsif follower_count > 1000
      count = 6
    elsif follower_count > 500
      count = 5
    elsif follower_count > 250
      count = 3
    elsif follower_count > 100
      count = 2      
    else
      count = 1
    end
    scale = [0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0][((id + Time.now.wday + Time.now.to_date.cweek) % 7)] # pick a scale val for today
    return (count * scale).round
  end

  def get_targeted_mention_twi_user_targets max_count
    follow_target_twi_users = []
    search_term_source = {}
    search_terms.shuffle.each do |search_term|
      next if follow_target_twi_users.size >= max_count
      statuses = Post.twitter_request { twitter.search(search_term.name, :count => 100).statuses }
      twi_users = statuses.select { |s| s.user.present? }.collect { |s| s.user }.uniq
      wisr_user_ids = User.where(twi_user_id: twi_users.collect(&:id)).collect(&:twi_user_id)
      twi_users.reject! { |twi_user| wisr_user_ids.include?(twi_user.id) or follow_target_twi_users.include?(twi_user.id) }
      twi_users.sample(max_count - follow_target_twi_users.size).each do |twi_user| 
        follow_target_twi_users << twi_user
        search_term_source[twi_user.id] = search_term
      end
    end
    puts "Too few targeted mention targets found for #{twi_screen_name} (only found #{follow_target_twi_users.size})!" if follow_target_twi_users.size < max_count
    return follow_target_twi_users, search_term_source  
  end  
end