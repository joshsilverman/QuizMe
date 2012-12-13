class Asker < User
  belongs_to :client
  has_many :questions, :foreign_key => :created_for_asker_id
  belongs_to :new_user_question, :class_name => 'Question', :foreign_key => :new_user_q_id

  default_scope where(:role => 'asker')

  def unresponded_count
    posts = Post.includes(:conversation).where("posts.requires_action = ? and posts.in_reply_to_user_id = ? and (posts.spam is null or posts.spam = ?) and posts.user_id not in (?)", true, id, false, Asker.all.collect(&:id))
    count = posts.not_spam.where("interaction_type = 2").count
    count += posts.not_spam.where("interaction_type = 4").count :user_id, :distinct => true

    count
  end

  def publish_question
    queue = self.publication_queue
    unless queue.blank?
      publication = queue.publications.order(:id)[queue.index]
      PROVIDERS.each { |provider| Post.publish(provider, self, publication) }
      queue.increment_index(self.posts_per_day)
      Rails.cache.delete("askers:#{self.id}:show")
    end
  end

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

  def self.engage_new_users
    askers = Asker.all
    new_user_questions = Question.find(askers.collect(&:new_user_q_id)).group_by(&:created_for_asker_id)
    askers.each do |asker|
      stop = false
      new_followers = Post.twitter_request { asker.twitter.follower_ids.ids.first(50) } || []
      new_followers.each do |tid|
        break if stop
        follow_response = Post.twitter_request { asker.twitter.follow(tid) }
        stop = true if follow_response.blank?
        sleep(1)
        user = User.find_or_create_by_twi_user_id(tid)
        next if new_user_questions[asker.id].blank? or asker.posts.where(:provider => 'twitter', :interaction_type => 4, :in_reply_to_user_id => user.id).count > 0
        p "sending dm to user: #{user.id}"
        Post.dm(asker, user, "Here's your first question! #{new_user_questions[asker.id][0].text}", {:intention => "initial question dm"})
        Mixpanel.track_event "DM question to new follower", {
          :distinct_id => user.id,
          :account => asker.twi_screen_name
        }
        sleep(1)   
      end
    end

    answered_dm_users = User.where("learner_level = 'dm answer' and created_at > ?", 1.week.ago).includes(:posts)
    app_posts = Post.where("in_reply_to_user_id in (?) and intention = 'new user question mention'", answered_dm_users.collect(&:id)).group_by(&:in_reply_to_user_id)
    popular_asker_publications = {}
    answered_dm_users.each do |user|
      if app_posts[user.id].blank?
        # asker = askers.find(user.posts.first.in_reply_to_user_id)
        asker = askers.select { |a| a.id == user.posts.first.in_reply_to_user_id }.first
        unless publication = popular_asker_publications[asker.id]
          if popular_post = asker.posts.includes(:conversations).where("created_at > ? and interaction_type = 1", 1.week.ago).sort_by {|p| p.conversations.size}.last
            publication_id = popular_post.publication_id
          else
            publication_id = asker.posts.where("interaction_type = 1").order("created_at DESC").limit(1).first.publication_id
          end
          publication = Publication.includes(:question).find(publication_id)
          popular_asker_publications[asker.id] = publication
        end
        puts "sending mention question to #{user.twi_screen_name}"
        Post.tweet(asker, "Next question! #{publication.question.text}", {
          :reply_to => user.twi_screen_name,
          :long_url => "#{URL}/feeds/#{asker.id}/#{publication.id}", 
          :interaction_type => 2, 
          :link_type => "mention_question", 
          :in_reply_to_user_id => user.id,
          :publication_id => publication.id,
          :intention => "new user question mention",
          :posted_via_app => true,
          :requires_action => false,
          :link_to_parent => false        
        })
        Mixpanel.track_event "new user question mention", {
          :distinct_id => user.id, 
          :account => asker.twi_screen_name
        }
      end 
    end

    ## NEED FOLLOWERS ASSOCIATION TO FIND UNENGAGED RECENT FOLLOWERS
    # users = User.where("learner_level = 'unengaged' or learner_level = 'dm answer' and created_at > ?", 1.week.ago).group_by(&:learner_level)
    # posts = Post.where("in_reply_to_user_id in (?)", users['unengaged'].collect(&:id)).order("created_at DESC").group_by(&:in_reply_to_user_id)
    # users['unengaged'].each do |user|
    #   if posts[user.id].present?
    #     last_post = posts[user.id].last
    #     if last_post.intention == "initial dm question" and last_post.created_at > 3.days.ago }
    #       # pick popular
    #       Post.dm(asker, user, "Pop quiz: #{new_user_questions[asker.id][0].text}", {:intention => "second attempt question dm"})
    #       Mixpanel.track_event "second attempt question DM", {
    #         :distinct_id => user.id,
    #         :account => asker.twi_screen_name
    #       }
    #       sleep(1)            
    #     end     
    #   end
    # end
    # posts = Post.where("in_reply_to_user_id in (?) and interaction_type = 2", users['dm answer'].collect(&:id)).group_by(&:in_reply_to_user_id)
    # users['dm answer'].each do |user|
    #   if posts[user.id].blank?
    #     # send mention question
    #     Post.tweet()
    #     Mixpanel.track_event "", {

    #     }
    #   end 
    # end
  end

  def self.reengage_incorrect_answerers
    askers = User.askers
    current_time = Time.now
    range_begin = 24.hours.ago
    range_end = 23.hours.ago
    
    puts "Current time: #{current_time}"
    puts "range = #{range_begin} - #{range_end}"
    
    recent_posts = Post.where("user_id is not null and ((correct = ? and created_at > ? and created_at < ? and interaction_type = 2) or ((intention = ? or intention = ?) and created_at > ?))", false, range_begin, range_end, 'reengage', 'incorrect answer follow up', range_end).includes(:user)
    user_grouped_posts = recent_posts.group_by(&:user_id)
    asker_ids = askers.collect(&:id)
    user_grouped_posts.each do |user_id, posts|
      # should ensure only one tweet per user as well here?
      next if asker_ids.include? user_id or recent_posts.where("(intention = ? or intention = ?) and in_reply_to_user_id = ?", 'reengage', 'incorrect answer follow up', user_id).present?
      incorrect_post = posts.sample
      # eww, think we need a cleaner way to access the question associated w/ a post
      question = incorrect_post.conversation.publication.question
      asker = User.askers.find(incorrect_post.in_reply_to_user_id)
      if Post.create_split_test(user_id, "mention reengagement", "response follow-up", "re-ask question") == "re-ask question"
        text = "Try this one again: #{question.text}"       
        link = false
      else 
        text = "Quick follow up... you missed this one yesterday, do you know it now?"
        link = true
      end
      # always link? another A/B test?
      # existing re-engages should be changed to follow-up!!!
      Post.tweet(asker, text, {
        :reply_to => incorrect_post.user.twi_screen_name,
        :long_url => "http://wisr.com/questions/#{question.id}/#{question.slug}",
        :in_reply_to_post_id => incorrect_post.id,
        :in_reply_to_user_id => user_id,
        :conversation_id => incorrect_post.conversation_id,
        :posted_via_app => true, 
        :requires_action => false,
        :interaction_type => 2,
        :link_to_parent => link,
        :link_type => "follow_up",
        :intention => "incorrect answer follow up"
      })  
      Mixpanel.track_event "incorrect answer follow up sent", {:distinct_id => user_id}
      puts "sending follow-up message to: #{user_id}"
      sleep(1)
    end
    puts "\n"       
  end 
   
  #here is an example of a function that cannot scale
  def self.leaderboard(id, data = {}, scores = [])
    posts = Post.select(:user_id).where(:in_reply_to_user_id => id, :correct => true).group_by(&:user_id).to_a.sort! {|a, b| b[1].length <=> a[1].length}[0..4]
    users = User.select([:twi_screen_name, :twi_profile_img_url, :id]).find(posts.collect {|post| post[0]}).group_by(&:id)
    posts.each { |post| scores << {:user => users[post[0]].first, :correct => post[1].length} }
    data[:scores] = scores
    return data
  end   
end