class Asker < User
  belongs_to :client
  has_many :questions, :foreign_key => :created_for_asker_id

  default_scope where(:role => 'asker')

  def update_followers
  	# Get lists of user ids from twitter + wisr
  	twi_follower_ids = self.twitter.follower_ids.ids
  	wisr_follower_ids = self.followers.collect(&:twi_user_id)

  	# Add new followers in wisr
  	(twi_follower_ids - wisr_follower_ids).each { |new_user_twi_id| self.followers << User.find_or_create_by_twi_user_id(new_user_twi_id) }

		# Remove unfollowers from asker follow association  	
  	unfollowed_users = User.where("twi_user_id in (?)", (wisr_follower_ids - twi_follower_ids))
  	unfollowed_users.each { |unfollowed_user| self.followers.delete(unfollowed_user) }
  	
  	return twi_follower_ids
  end 

  def self.reengage_inactive_users
  	### ENSURE WE DONT SEND QUESTIONS ALREADY ANSWERED BY THE USER
  	
    # sent_to = []

  	# Strategy definition
  	strategy = [3, 7, 10]

		# Lock current time  	
  	now = Time.now

  	# Get disengaging users
		disengaging_users = User.includes(:posts)\
			.where("users.last_interaction_at < ? and users.last_interaction_at > ?", (now - strategy.first.days), (now - (strategy.sum.days + 1.day)))\
			.where("posts.created_at > ? and posts.correct is not null", (now - (strategy.sum.days + 1.day)))

		# Get recently sent re-engagements
		recent_reengagements = Post.where("in_reply_to_user_id in (?)", disengaging_users.collect(&:id))\
			.where("intention = 'reengage inactive'")\
			.where("created_at > ?", (now - (strategy.sum.days + 1.day)))

		# Compile recipients by asker
		asker_recipients = {}
		disengaging_users.each do |user|
			user_reengagments = recent_reengagements.select { |p| p.in_reply_to_user_id == user.id }.sort_by(&:created_at)
			next_checkpoint = strategy[user_reengagments.size]
			next if next_checkpoint.blank?
			if user_reengagments.blank? or ((now - user_reengagments.last.created_at) > next_checkpoint.days)
				sample_asker_id = user.posts.sample.in_reply_to_user_id
				asker_recipients[sample_asker_id] ||= {:recipients => []}
				asker_recipients[sample_asker_id][:recipients] << {:user => user, :interval => strategy[user_reengagments.size]}					
			end
		end

		# Get popular publications
		Post.includes(:conversations).where("posts.user_id in (?) and posts.created_at > ? and posts.interaction_type = 1", asker_recipients.keys, 5.weeks.ago).group_by(&:user_id).each do |user_id, posts|
      asker_recipients[user_id][:publication] = posts.sort_by{|p| p.conversations.size}.last.publication
    end		  

    # Send tweets
    asker_recipients.each do |asker_id, recipient_data|
    	asker = Asker.find(asker_id)
    	follower_ids = asker.update_followers()
    	publication = recipient_data[:publication]
    	question = publication.question
    	next unless asker and publication
    	recipient_data[:recipients].each do |user_hash|
    		user = user_hash[:user]
    		next unless follower_ids.include? user.twi_user_id
    		option_text = Post.create_split_test(user.id, "reengage last week inactive", "Pop quiz:","A question for you:","Do you know the answer?","Quick quiz:","We've missed you!")    		
        Post.tweet(asker, "#{option_text} #{question.text}", {
          :reply_to => user.twi_screen_name,
          :long_url => "http://wisr.com/feeds/#{asker.id}/#{publication.id}",
          :in_reply_to_user_id => user.id,
          :posted_via_app => true,
          :publication_id => publication.id,  
          :requires_action => false,
          :interaction_type => 2,
          :link_to_parent => false,
          :link_type => "reengage",
          :intention => "reengage inactive"
        })
        Mixpanel.track_event "reengage inactive", {:distinct_id => user.id, :interval => user_hash[:interval]}
        sleep(1)
    		# puts "sending reengagement to #{user.twi_screen_name} (interval = #{user_hash[:interval]})"
    		# Post.create({
    		# 	:in_reply_to_user_id => user.id,
    		# 	:user_id => asker.id,
    		# 	:intention => "reengage inactive",
    		# 	:created_at => now
    		# })
        # sent_to << user.id
      end
    end
    # puts "#{sent_to.size == sent_to.uniq.size} (#{sent_to.size} / #{sent_to.uniq.size})"
  end   
end