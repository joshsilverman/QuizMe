module ManageTwitterRelationships

  def autofollow options = {}
    # Check if we should follow
    return unless (max_follows = autofollow_count) > 0

    # Twi search to get follow targets
    twi_user_ids = options[:twi_user_ids] || get_follow_target_twi_ids(max_follows)

    # Send follow requests
    send_autofollows(twi_user_ids, max_follows, options[:force])
  end

  def autofollow_count max_follows = nil
    # Check if we should follow today
    max_follows ||= [0, 0, 9, 4, 12, 2, 11][((id + Time.now.wday + Time.now.to_date.cweek) % 7)]
    return 0 if max_follows == 0

    # Check if we should follow during this part of the day
    return 0 if Time.now.hour <= ((id + Time.now.wday + Time.now.to_date.cweek) % 6)
    return 0 if Time.now.hour > ((id + Time.now.wday + Time.now.to_date.cweek) % 6 + 18)

    # Check if we've already followed enough users today
    return 0 if relationships.search.where("created_at > ?", Time.now.beginning_of_day).size >= max_follows

    max_follows
  end

  def get_follow_target_twi_ids max_follows
    follow_target_twi_user_ids = []
    wisr_follows_ids = follows_with_inactive.collect(&:twi_user_id)
    search_terms.collect(&:name).shuffle.each do |search_term|
      next if follow_target_twi_user_ids.size >= max_follows
      twi_user_ids = Post.twitter_request { twitter.search(search_term, :count => 100).statuses.collect { |s| s.user.id }.uniq }
      twi_user_ids.reject! { |twi_user_id| wisr_follows_ids.include?(twi_user_id) or follow_target_twi_user_ids.include?(twi_user_id) }
      twi_user_ids.sample(max_follows - follow_target_twi_user_ids.size).each { |twi_user_id| follow_target_twi_user_ids << twi_user_id }
    end
    puts "Too few autofollows found!" if follow_target_twi_user_ids.size < max_follows
    follow_target_twi_user_ids
  end

  def send_autofollows twi_user_ids, max_follows, force = false
    twi_user_ids.sample(max_follows).each do |twi_user_id|
      # puts "send_autofollow follow"
      response = Post.twitter_request { twitter.follow(twi_user_id) }
      if response.present? or force
        user = User.find_or_create_by_twi_user_id(twi_user_id)    
        add_follow(user, 2)
      end 
      sleep((5..60).to_a.sample) unless force # avoids sleep in tests
    end
  end

  def update_relationships
    twi_follows_ids = request_and_update_follows
    twi_follower_ids = request_and_update_followers

    followback(twi_follower_ids) unless twi_follower_ids.blank?
    unfollow_nonreciprocal(twi_follows_ids) unless twi_follows_ids.blank?
    unfollow_oldest_inactive_user
  end

  # FOLLOWS METHODS
  def request_and_update_follows
    twi_follows_ids = Post.twitter_request { twitter.friend_ids.ids }
    update_follows(twi_follows_ids, follows.collect(&:twi_user_id)) if twi_follows_ids.present?
  end

  def update_follows twi_follows_ids, wisr_follows_ids
    # Add new friends in wisr
    (twi_follows_ids - wisr_follows_ids).each do |new_user_twi_id| 
      add_follow(User.find_or_create_by_twi_user_id(new_user_twi_id)) # Should have a type_id?     
    end

    # Remove unfollows from asker follow association    
    User.where("twi_user_id in (?)", (wisr_follows_ids - twi_follows_ids)).each { |unfollowed_user| remove_follow(unfollowed_user) }
    
    twi_follows_ids 
  end

  def unfollow_nonreciprocal twi_follows_ids, limit = 1.month.ago
    nonreciprocal_follower_ids = User.find_all_by_twi_user_id(twi_follows_ids - followers.collect(&:twi_user_id)).collect(&:id)
    nonreciprocal_follower_ids = [0] if nonreciprocal_follower_ids.empty?
    relationships.active.where('updated_at < ? AND followed_id IN (?)', limit, nonreciprocal_follower_ids).each do |nonreciprocal_relationship|
      user = User.find(nonreciprocal_relationship.followed_id)
      Post.twitter_request { twitter.unfollow(user.twi_user_id) }
      remove_follow(user)
    end
  end 

  def unfollow_oldest_inactive_user limit = 3.months.ago
    if oldest_inactive_user = follows.includes(:posts).where("users.created_at < ? and posts.user_id is null", limit).order("users.created_at ASC").limit(1).first
      Post.twitter_request { twitter.unfollow(oldest_inactive_user.twi_user_id) }
      remove_follow(oldest_inactive_user)
    end
  end 

  def add_follow user, type_id = nil
    relationship = Relationship.find_or_create_by_followed_id_and_follower_id(user.id, id)
    relationship.update_attributes(active: true, type_id: type_id, pending: false)
  end

  def remove_follow user
    relationship = Relationship.find_by_followed_id_and_follower_id(user.id, id)
    relationship.update_attribute :active, false if relationship
  end  

  # FOLLOWER METHODS
  def request_and_update_followers
    twi_follower_ids = Post.twitter_request { twitter.follower_ids.ids }
    update_followers(twi_follower_ids, followers.collect(&:twi_user_id)) if twi_follower_ids.present?
  end

  def update_followers twi_follower_ids, wisr_follower_ids
    # Add new followers in wisr
    asker_follows = follows
    (twi_follower_ids - wisr_follower_ids).each do |new_user_twi_id|
      follower = User.find_or_create_by_twi_user_id(new_user_twi_id)
      follower_type_id = asker_follows.include?(follower) ? 1 : 3
      add_follower(follower, follower_type_id)
    end

    # Remove unfollowers from asker follow association    
    User.where("twi_user_id in (?)", (wisr_follower_ids - twi_follower_ids)).each { |unfollowed_user| remove_follower(unfollowed_user) }

    twi_follower_ids 
  end 

  def followback twi_follower_ids
    return if relationships.search.where("created_at > ?", Time.now.beginning_of_day).size >= 20
    
    twi_pending_ids = Post.twitter_request { twitter.friendships_outgoing.ids }
    i = 0

    (twi_follower_ids - follows.collect(&:twi_user_id)).each do |twi_user_id|
      puts "followback follow twi_user_id #{twi_user_id} on #{twi_screen_name}"
      user = User.find_or_create_by_twi_user_id(twi_user_id)
      user_relationships = relationships.where("followed_id = ?", user.id)

      if user_relationships.where("pending = ?", true).present?
        puts "Skip followback again -- request pending"
        next
      elsif twi_pending_ids.include? twi_user_id
        puts "Skip followback -- request pending"
        relationships.find_or_create_by_followed_id(user.id).update_attribute :pending, true
        next
      elsif user_relationships.where("type_id = 4").present?
        puts "Skip followback -- account was suspended (?)"
        next
      elsif user_relationships.where("active = false").present?
        puts "Skip followback -- user was inactive unfollowed"
        next
      end

      if i >= 1
        puts "Too many followbacks (1) to run all now"
        return
      end
      i += 1

      puts "Send request"
      response = Post.twitter_request { twitter.follow(twi_user_id) }
      if response.nil?
        puts "possible suspended acct, setting relationship to suspended"
        relationships.find_or_create_by_followed_id(user.id).update_attributes(type_id: 4, active: false) 
        next
      end
      add_follow(user, 1)
    end
  end

  def add_follower user, type_id = nil
    relationship = Relationship.find_or_create_by_followed_id_and_follower_id(id, user.id)
    relationship.update_attributes(active: true, type_id: type_id, pending: false)
    send_new_user_question(user)
    user.segment
  end

  def remove_follower user
    relationship = Relationship.find_by_followed_id_and_follower_id(id, user.id)
    relationship.update_attribute :active, false if relationship
    user.segment
  end
end