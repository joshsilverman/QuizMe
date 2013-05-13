module ManageTwitterRelationships

  # dont follow anyone two days a week
  # 1-3 follow sessions per day 
  # 1-10 seconds delay between follows
  # sessions occur within an 18 hour-period
  # 1-6 hours between follow sessions

  def autofollow
    return unless (max_follows = should_autofollow) > 0

    # TODO handle not enough users returned
    twi_users = Post.twitter_request { twitter.search(search_terms.sample.name, :count => 100).statuses.collect { |s| s.user }.uniq }    
    wisr_follows_ids = follows.collect(&:twi_user_id)
    twi_users.reject! { |u| wisr_follows_ids.include? u.id }

    send_autofollows(twi_users.collect(&:id), max_follows)
  end

  def autofollow_count
    # Check if we should follow today
    # puts (id + Date.today.wday + Date.today.cweek)
    max_follows = [0, 0, 9, 4, 12, 2, 11][((id + Time.now.wday + Time.now.to_date.cweek) % 7)]
    return 0 if max_follows == 0

    return 0 if Time.now.hour <= ((id + Time.now.wday + Time.now.to_date.cweek) % 6)
    return 0 if Time.now.hour > ((id + Time.now.wday + Time.now.to_date.cweek) % 6 + 18)

    return 0 if relationships.search.where("created_at > ?", Time.now.beginning_of_day).size >= max_follows

    max_follows
  end

  def send_autofollows twi_user_ids, max_follows, force = false
    twi_user_ids.sample(max_follows).each do |twi_user_id|
      response = Post.twitter_request { twitter.follow(twi_user_id) }
      if response.present? or force
        user = User.find_or_create_by_twi_user_id(twi_user_id)    
        add_follow(user, 2)
      end 
    end
  end


  def update_relationships
    twi_follows_ids = request_and_update_follows
    twi_follower_ids = request_and_update_followers

    followback(twi_follower_ids)
    unfollow_nonreciprocal(twi_follows_ids)
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
    nonreciprocal_follower_ids = (twi_follows_ids - followers.collect(&:twi_user_id))
    relationships.where('active = ? and updated_at < ? and followed_id not in (?)', true, limit, nonreciprocal_follower_ids).each do |nonreciprocal_relationship|
      user = User.find(nonreciprocal_relationship.followed_id)
      Post.twitter_request { twitter.unfollow(user.twi_user_id) }
      remove_follow(user)
    end
  end  

  def add_follow user, type_id = nil
    relationship = Relationship.find_or_create_by_followed_id_and_follower_id(user.id, id)
    relationship.update_attributes(active: true, type_id: type_id)
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
    (twi_follower_ids - wisr_follower_ids).each do |new_user_twi_id| 
      follower = User.find_or_create_by_twi_user_id(new_user_twi_id)
      follower_type_id = follows.include?(follower) ? 1 : 3
      add_follower(follower, follower_type_id)
    end

    # Remove unfollowers from asker follow association    
    User.where("twi_user_id in (?)", (wisr_follower_ids - twi_follower_ids)).each { |unfollowed_user| remove_follower(unfollowed_user) }

    twi_follower_ids 
  end 

  def followback twi_follower_ids
    (twi_follower_ids - follows.collect(&:twi_user_id)).each do |twi_user_id|
      Post.twitter_request { twitter.follow(twi_user_id) }
      user = User.find_or_create_by_twi_user_id(twi_user_id)
      add_follow(user, 1)
    end
  end

  def add_follower user, type_id = nil
    relationship = Relationship.find_or_create_by_followed_id_and_follower_id(id, user.id)
    relationship.update_attributes(active: true, type_id: type_id)
    send_new_user_question(user)
    user.segment
  end

  def remove_follower user
    relationship = Relationship.find_by_followed_id_and_follower_id(id, user.id)
    relationship.update_attribute :active, false if relationship
    user.segment
  end
end