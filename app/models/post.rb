class Post < ActiveRecord::Base
	belongs_to :question
	belongs_to :user
  belongs_to :asker, :class_name => "User", :foreign_key => 'asker_id'

  belongs_to :publication
  belongs_to :conversation
	belongs_to :parent, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_one :child, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_many :conversations
	has_many :reps

  scope :not_spam, where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)
  scope :not_us, where('user_id NOT IN (?)', Asker.all.collect(&:id) + ADMINS)
  scope :social, where('interaction_type IN (2,3)')

  @@classifier = Classifier.new
  
  def self.classifier
    @@classifier
  end

  def self.format_tweet(text, options = {})
    generate_tweet = lambda { |x|
      (options[:in_reply_to_user].present? ? "@#{options[:in_reply_to_user]} " : "") +
      (x > 0 ? "#{text} " : "#{text[0..(-1 + x)]}... ") + 
      (options[:question_backlink].present? ? "#{options[:question_backlink]} " : "") +
      (options[:hashtag].present? ? "##{options[:hashtag]} " : "") +
      (options[:resource_backlink].present? ? "#{options[:wisr_question] ? 'Find the answer at' : 'Find out why at'} #{options[:resource_backlink]} " : "") +
      (options[:via_user].present? ? "via @#{options[:via_user]}" : "") + 
      (options[:buffer].present? ? (" " * options[:buffer]) : "")
    }
    if options[:return_text_only]
      x = (140 - generate_tweet.call(0).length)
      return (x > 0 ? "#{text}" : "#{text[0..(-1 + x)]}...")
    else
      return generate_tweet.call(140 - generate_tweet.call(0).length).strip
    end
  end

	def self.shorten_url(url, source, lt, campaign, show_answer=nil)
    Shortener.shorten("#{url}?s=#{source}&lt=#{lt}&c=#{campaign}#{'&ans=true' if show_answer}").short_url
	end

  def self.publish(provider, asker, publication)
    return unless publication and question = publication.question
    if question.user_id == 1
      via = nil
    else
      via = question.user.twi_screen_name
    end
    long_url = "#{URL}/feeds/#{asker.id}/#{publication.id}"
    case provider
    when "twitter"
      begin         
        Post.tweet(asker, question.text, {
          :hashtag => (ACCOUNT_DATA[asker.id] ? ACCOUNT_DATA[asker.id][:hashtags].sample : nil), 
          :long_url => long_url, 
          :interaction_type => 1, 
          :link_type => 'initial', 
          :publication_id => publication.id, 
          :link_to_parent => false, 
          :via => via
        })
        publication.update_attribute(:published, true)
        question.update_attribute(:priority, false) if question.priority
        if via.present? and question.priority
          Post.tweet(asker, "We thought you might like to know that your question was just published on #{asker.twi_screen_name}", {
            :reply_to => via, 
            :long_url => long_url, 
            :interaction_type => 2, 
            :link_type => "ugc", 
            :link_to_parent => false
          })        
        end
      rescue Exception => exception
        puts "exception while publishing tweet"
        puts exception.message
      end
    when "tumblr"
      puts "No Tumblr Post Methods"
    when "facebook"
      puts "No Tumblr Post Methods"
    else  
      puts "Boo"
    end
  end

  def self.tweet(user, text, options = {})
    short_url = Post.shorten_url(options[:long_url], 'twi', options[:link_type], user.twi_screen_name) if options[:long_url]
    short_resource_url = Post.shorten_url(options[:resource_url], 'twi', "res", user.twi_screen_name, options[:wisr_question]) if options[:resource_url]
    tweet = Post.format_tweet(text, {
      :in_reply_to_user => options[:reply_to],
      :question_backlink => short_url,
      :hashtag => options[:hashtag],
      :resource_backlink => short_resource_url,
      :via_user => options[:via],
      :wisr_question => options[:wisr_question]
    })
    if options[:in_reply_to_post_id] and options[:link_to_parent]
      parent_post = Post.find(options[:in_reply_to_post_id]) 
      twitter_response = Post.twitter_request { user.twitter.update(tweet, {'in_reply_to_status_id' => parent_post.provider_post_id.to_i}) }
    else
      twitter_response = Post.twitter_request { user.twitter.update(tweet) }
    end
    post = nil
    if twitter_response
      options[:in_reply_to_user_id] = [options[:in_reply_to_user_id]] unless options[:in_reply_to_user_id].is_a?(Array)
      options[:in_reply_to_user_id].each do |user_id|
        post = Post.create(
          :user_id => user.id,
          :provider => 'twitter',
          :text => tweet,
          :provider_post_id => twitter_response.id.to_s,
          :in_reply_to_post_id => options[:in_reply_to_post_id],
          :in_reply_to_user_id => user_id,
          :conversation_id => options[:conversation_id],
          :publication_id => options[:publication_id],
          :url => options[:long_url] ? short_url : nil,
          :posted_via_app => true, 
          :requires_action => (options[:requires_action].present? ? options[:requires_action] : false),
          :interaction_type => options[:interaction_type],
          :correct => options[:correct],
          :intention => options[:intention]
        )
        if options[:publication_id]
          publication = Publication.find(options[:publication_id])
          publication.posts << post
        end
      end
    end
    return post        
  end

  def self.dm(user, recipient, text, options = {})    
    short_url = Post.shorten_url(options[:long_url], 'twi', options[:link_type], user.twi_screen_name) if options[:long_url]
    begin
      res = user.twitter.direct_message_create(recipient.twi_user_id, text)
      post = Post.create(
        :user_id => user.id,
        :provider => 'twitter',
        :text => text,
        :provider_post_id => res.id.to_s,
        :in_reply_to_post_id => options[:in_reply_to_post_id],
        :in_reply_to_user_id => recipient.id,
        :conversation_id => options[:conversation_id],
        :url => options[:long_url] ? short_url : nil,
        :posted_via_app => true,
        :requires_action => false,
        :interaction_type => 4,
        :intention => options[:intention]
      )
    rescue Exception => exception
      puts "exception in DM user"
      puts exception.message
    end    
    return post
  end

  def self.app_response(current_user, asker_id, publication_id, answer_id)
    asker = User.asker(asker_id)
    publication = Publication.find(publication_id)
    answer = Answer.select([:text, :correct]).find(answer_id)
    status = (answer.correct ? "correct" : "incorrect")
    post = publication.posts.where(:provider => "twitter").first
    # conversation = Conversation.find_or_create_by_user_id_and_post_id_and_publication_id(current_user.id, post.id, publication_id) 
    conversation = Conversation.create({
      :user_id => current_user.id,
      :post_id => post.id,
      :publication_id => publication_id
    })

    post_to_twitter = Post.create_split_test(current_user.id, "wisr posts propagate to twitter", "true", "false")
    post_aggregate_activity = Post.create_split_test(current_user.id, "post aggregate activity", "false", "true")
    if post_aggregate_activity == "false"
      user_post = Post.tweet(current_user, answer.text, {
        :reply_to => asker.twi_screen_name,
        :long_url => "#{URL}/feeds/#{asker.id}/#{publication_id}", 
        :interaction_type => 2, 
        :link_type => status[0..2], 
        :conversation_id => conversation.id, 
        :in_reply_to_post_id => post.id, 
        :in_reply_to_user_id => asker.id,
        :link_to_parent => false, 
        :correct => answer.correct,
        :intention => 'respond to question'
      })
    else
      user_post = Post.create({
        :user_id => current_user.id,
        :provider => 'wisr',
        :text => answer.text,
        :in_reply_to_post_id => post.id, 
        :in_reply_to_user_id => asker.id,
        :conversation_id => conversation.id,
        :posted_via_app => true, 
        :requires_action => false,
        :interaction_type => 2,
        :correct => answer.correct,
        :intention => 'respond to question'
      })
      current_cache = (Rails.cache.read("aggregate activity") ? Rails.cache.read("aggregate activity").dup : {})
      current_cache[current_user.id] ||= {:askers => {}}
      current_cache[current_user.id][:twi_screen_name] = current_user.twi_screen_name
      current_cache[current_user.id][:askers][asker.id] ||= Hash.new(0)
      current_cache[current_user.id][:askers][asker.id][:last_answer_at] = Time.now
      current_cache[current_user.id][:askers][asker.id][:count] += 1
      current_cache[current_user.id][:askers][asker.id][:correct] += 1 if answer.correct
      Rails.cache.write("aggregate activity", current_cache)
      # p Rails.cache.read("aggregate activity")
    end

    if user_post
      conversation.posts << user_post
      user_post.update_responded(answer.correct, publication_id, publication.question_id, asker_id)
      current_user.update_user_interactions({
        :learner_level => "feed answer", 
        :last_interaction_at => user_post.created_at,
        :last_answer_at => user_post.created_at
      })        
      response_text = post.generate_response(status)
      publication.question.resource_url ? resource_url = "#{URL}/posts/#{post.id}/refer" : resource_url = "#{URL}/questions/#{publication.question_id}/#{publication.question.slug}"
      
      if post_aggregate_activity == "false"
        app_post = Post.tweet(asker, response_text, {
          :reply_to => current_user.twi_screen_name,
          :long_url => "#{URL}/feeds/#{asker.id}/#{publication_id}", 
          :interaction_type => 2, 
          :link_type => status[0..2], 
          :conversation_id => conversation.id, 
          :in_reply_to_post_id => (user_post ? user_post.id : nil), 
          :in_reply_to_user_id => current_user.id,
          :link_to_parent => true, 
          :resource_url => answer.correct ? nil : resource_url,
          :wisr_question => publication.question.resource_url ? false : true,
          :intention => 'grade'
        })  
      else
        if resource_url and answer.correct == false
          short_resource_url = Post.shorten_url(
            resource_url, 
            'wisr', 
            'res', 
            current_user.twi_screen_name, 
            publication.question.resource_url ? false : true
          )
          response_text += " Find the answer at #{short_resource_url}" if short_resource_url.present?
        end
        app_post = Post.create({
          :user_id => asker.id,
          :provider => 'wisr',
          :text => response_text,
          :in_reply_to_post_id => user_post.id,
          :in_reply_to_user_id => current_user.id,
          :conversation_id => conversation.id,
          :url => answer.correct ? short_resource_url : nil,
          :posted_via_app => true, 
          :requires_action => false,
          :interaction_type => 2,
          :intention => 'grade'
        })
      end

      # Check if we should ask for UGC
      User.request_ugc(current_user, asker)

      in_reply_to = nil
      if Post.joins(:conversation).where("posts.intention = ? and posts.in_reply_to_user_id = ? and conversations.publication_id = ?", 'incorrect answer follow up', current_user.id, publication_id).present?
        Post.trigger_split_test(current_user.id, 'mention reengagement') 
        in_reply_to = "incorrect answer follow up"  
      elsif Post.joins(:conversation).where("posts.intention = ? and posts.in_reply_to_user_id = ? and conversations.publication_id = ?", 'new user question mention', current_user.id, publication_id).present?
        in_reply_to = "new follower question mention"
      end
      if Post.where("in_reply_to_user_id = ? and (intention = ? or intention = ?)", current_user.id, 'reengage inactive', 'reengage last week inactive').present?
        Post.trigger_split_test(current_user.id, 'reengage last week inactive') 
        Post.trigger_split_test(current_user.id, 'cohort re-engagement') 
      end
      Post.trigger_split_test(current_user.id, 'wisr posts propagate to twitter') if current_user.posts.where("intention = ? and created_at < ?", 'twitter feed propagation experiment', 1.day.ago).present?
      
      Mixpanel.track_event "answered", {
        :distinct_id => current_user.id,
        :account => asker.twi_screen_name,
        :type => "app", 
        :in_reply_to => in_reply_to
      }
    end
    return conversation
  end

  def self.create_tumblr_post(current_acct, text, url, lt, question_id, parent_id)
    short_url = Post.shorten_url(url, 'tum', lt, current_acct.twi_screen_name, question_id)
    res = current_acct.tumblr.text(
      current_acct.tum_url,
      :title => "Daily Quiz!",
      :body => "#{text} #{short_url}"
    )
    Post.create(
      :asker_id => current_acct.id,
      :question_id => question_id,
      :provider => 'tumblr',
      :text => text,
      :url => short_url,
      :link_type => lt,
      :post_type => 'text',
      :provider_post_id => res.id.to_s,
      :parent_id => parent_id,
      :interaction_type => 1
    )
  end


  ###
  ### Getting and Setting Posts retrieved from Twitter
  ###

  def self.check_for_posts(current_acct)
    # asker_ids = User.askers.collect(&:id)
    # last_post = Post.where("provider like ? and provider_post_id is not null and user_id not in (?) and posted_via_app = ?", 'twitter', asker_ids, false,).order('created_at DESC').limit(1).last
    # last_dm = Post.where("provider like ? and provider_post_id is not null and user_id not in (?) and posted_via_app = ?", 'twitter', asker_ids, false).order('created_at DESC').limit(1).last
    # mentions = Post.twitter_request { client.mentions({:count => 50, :since_id => last_post.nil? ? nil : last_post.provider_post_id.to_i}) } || []
    # retweets = Post.twitter_request { client.retweets_of_me({:count => 50}) } || []
    # dms = Post.twitter_request { client.direct_messages({:count => 50, :since_id => last_dm.nil? ? nil : last_dm.provider_post_id.to_i}) } || []
    puts current_acct.twi_screen_name

    client = current_acct.twitter

    # Get mentions, de-dupe, and save
    # last_mention = Post.where("provider_post_id is not null and in_reply_to_user_id = ?", current_acct.id)
    mentions = Post.twitter_request { client.mentions({:count => 200}) } || []
    existing_mention_ids = Post.select(:provider_post_id).where(:provider_post_id => mentions.collect { |m| m.id.to_s }).collect(&:provider_post_id)
    mentions.reject! { |m| existing_mention_ids.include? m.id.to_s }
    mentions.each { |m| Post.save_mention_data(m, current_acct) }

    # Get DMs, de-dupe, and save
    dms = Post.twitter_request { client.direct_messages({:count => 200}) } || []
    existing_dm_ids = Post.select(:provider_post_id).where(:provider_post_id => dms.collect { |dm| dm.id.to_s }).collect(&:provider_post_id)
    dms.reject! { |dm| existing_dm_ids.include? dm.id.to_s }
    dms.each { |d| Post.save_dm_data(d, current_acct) }
    
    # Get RTs and save
    retweets = Post.twitter_request { client.retweets_of_me({:count => 50}) } || []
    retweets.each { |r| Post.save_retweet_data(r, current_acct) }

    true 
  end

  def self.save_mention_data(m, current_acct)
    u = User.find_or_create_by_twi_user_id(m.user.id)
    u.update_attributes(
      :twi_name => m.user.name,
      :twi_screen_name => m.user.screen_name,
      :twi_profile_img_url => m.user.status.nil? ? nil : m.user.status.user.profile_image_url
    )

    in_reply_to_post = Post.find_by_provider_post_id(m.in_reply_to_status_id.to_s) if m.in_reply_to_status_id
    if in_reply_to_post
      conversation_id = in_reply_to_post.conversation_id || Conversation.create(:publication_id => in_reply_to_post.publication_id, :post_id => in_reply_to_post.id, :user_id => u.id).id
      in_reply_to_post.update_attribute(:conversation_id, conversation_id)
    else
      conversation_id = nil
      puts "No in reply to post"
    end

    post = Post.create( 
      :provider_post_id => m.id.to_s,
      :text => m.text,
      :provider => 'twitter',
      :user_id => u.id,
      :in_reply_to_post_id => in_reply_to_post.try(:id),
      :in_reply_to_user_id => current_acct.id,
      :created_at => m.created_at,
      :conversation_id => conversation_id,
      :posted_via_app => false,
      :interaction_type => 2,
      :requires_action => true
    )

    u.update_user_interactions({
      :learner_level => "mention",
      :last_interaction_at => post.created_at
    })

    # puts "missed item in stream! mention: #{post.to_json}" if STREAMING_ACCOUNT.id == current_acct.id

    Post.classifier.classify post
    Stat.update_stat_cache("mentions", 1, current_acct.id, post.created_at, u.id) unless u.role == "asker"
    Stat.update_stat_cache("active_users", u.id, current_acct.id, post.created_at, u.id) unless u.role == "asker"
  end

  def self.save_dm_data(d, current_acct)
    u = User.find_or_create_by_twi_user_id(d.sender.id)
    u.update_attributes(
      :twi_name => d.sender.name,
      :twi_screen_name => d.sender.screen_name,
      :twi_profile_img_url => d.sender.profile_image_url
    )

    in_reply_to_post = Post.where("provider = ? and interaction_type = 4 and (user_id = ? or (user_id = ? and in_reply_to_user_id = ?))", 'twitter', u.id, current_acct.id, u.id)\
      .order("created_at DESC")\
      .limit(1)\
      .first

    if in_reply_to_post
      conversation_id = in_reply_to_post.conversation_id || Conversation.create(:post_id => in_reply_to_post.id, :user_id => u.id).id

      # Removes need to hide multiple DMs in same thread
      in_reply_to_post.update_attribute(:requires_action, false)
    else
      conversation_id = nil
      puts "No in reply to dm"
    end

    # possible issue w/ origin dm and its response being collected 
    # in same rake, then being created in the wrong order
    post = Post.create( 
      :provider_post_id => d.id.to_s,
      :text => d.text,
      :provider => 'twitter',
      :user_id => u.id,
      :in_reply_to_post_id => in_reply_to_post.try(:id),
      :in_reply_to_user_id => current_acct.id,
      :created_at => d.created_at,
      :conversation_id => conversation_id,
      :posted_via_app => false,
      :interaction_type => 4,
      :requires_action => true
    )

    u.update_user_interactions({
      :learner_level => "dm", 
      :last_interaction_at => post.created_at
    })

    # puts "missed item in stream! DM: #{post.to_json}" if STREAMING_ACCOUNT.id == current_acct.id

    Post.classifier.classify post
  end

  def self.save_retweet_data(r, current_acct, attempts = 0)
    retweeted_post = Post.find_by_provider_post_id(r.id.to_s) || Post.create({:provider_post_id => r.id.to_s, :user_id => current_acct.id, :provider => "twitter", :text => r.text})    
    users = Post.twitter_request { current_acct.twitter.retweeters_of(r.id) } || []
    users.each do |user|
      u = User.find_or_create_by_twi_user_id(user.id)

      post = Post.where("user_id = ? and in_reply_to_post_id = ? and interaction_type = 3", u.id, retweeted_post.id).first
      
      return if post

      u.update_attributes(
        :twi_name => user.name,
        :twi_screen_name => user.screen_name,
        :twi_profile_img_url => user.profile_image_url
      )

      post = Post.create(
        :provider => 'twitter',
        :user_id => u.id,
        :in_reply_to_post_id => retweeted_post.id,
        :in_reply_to_user_id => retweeted_post.user_id,
        :posted_via_app => false,
        :created_at => r.created_at,
        :interaction_type => 3,
        :requires_action => true,
        :text => retweeted_post.text
      )

      u.update_user_interactions({
        :learner_level => "share", 
        :last_interaction_at => post.created_at
      })

      if retweeted_post.intention == 'post aggregate activity' or retweeted_post.intention == 'grade'
        Post.trigger_split_test(u.id, 'post aggregate activity') 
      end

      # puts "missed item in stream! RT: #{post.to_json}" if STREAMING_ACCOUNT.id == current_acct.id

      Stat.update_stat_cache("retweets", 1, current_acct.id, post.created_at, u.id) unless u.role == "asker"
      Stat.update_stat_cache("active_users", u.id, current_acct.id, post.created_at, u.id) unless u.role == "asker"
    end
  end


  def self.save_post(interaction_type, tweet, asker_id, conversation_id = nil)
    puts "saving post from stream (#{interaction_type}):"
    puts "#{tweet.text} (ppid: #{tweet.id.to_s})"

    return if Post.find_by_provider_post_id(tweet.id.to_s)

    if interaction_type == 4
      twi_user = tweet.sender
      user = User.find_or_create_by_twi_user_id(tweet.sender.id.to_s)
      in_reply_to_post = Post.where("provider = 'twitter' and interaction_type = 4 and ((user_id = ? and in_reply_to_user_id = ?) or (user_id = ? and in_reply_to_user_id = ?))", asker_id, user.id, user.id, asker_id)\
        .order("created_at DESC")\
        .limit(1)\
        .first
      learner_level = "dm"
    else
      twi_user = tweet.user
      user = User.find_or_create_by_twi_user_id(tweet.user.id.to_s)
      if interaction_type == 2 
        in_reply_to_post = Post.find_by_provider_post_id(tweet.in_reply_to_status_id.to_s)
        learner_level = "mention"
      else
        in_reply_to_post = Post.find_by_provider_post_id(tweet.retweeted_status.id.to_s)
        learner_level = "share"
      end
    end
    
    user.update_attributes({
      :twi_name => twi_user.name,
      :twi_screen_name => twi_user.screen_name,
      :twi_profile_img_url => twi_user.profile_image_url
    })

    if in_reply_to_post
      unless conversation_id = in_reply_to_post.conversation_id
        conversation_id = Conversation.create(:publication_id => in_reply_to_post.publication_id, :post_id => in_reply_to_post.id, :user_id => user.id).id
        in_reply_to_post.update_attribute(:conversation_id, conversation_id)
      end
    end

    post = Post.create({
      :user_id => user.id, 
      :provider => 'twitter',
      :text => (interaction_type == 3 ? in_reply_to_post.try(:text) : tweet.text),
      :provider_post_id => tweet.id.to_s,
      :created_at => tweet.created_at,
      :in_reply_to_post_id => in_reply_to_post.try(:id),
      :conversation_id => conversation_id,
      :requires_action => true,
      :in_reply_to_user_id => asker_id,
      :posted_via_app => false,
      :interaction_type => interaction_type
    })

    user.update_user_interactions({
      :learner_level => learner_level, 
      :last_interaction_at => post.created_at
    })

    Post.classifier.classify post
  end

  def generate_response(response_type)
    #Include backlink if exists
    case response_type
    when 'correct'
      tweet = "#{CORRECT.sample} #{COMPLEMENT.sample}"
    when 'incorrect'
      tweet = "#{INCORRECT.sample}" #" Check the question and try it again!"
    when 'fast'
      tweet = "#{FAST.sample} @#{self.user.twi_screen_name} had the fastest right answer on that one!"
    else
      tweet = ""
    end
    tweet
  end

  def update_responded(correct, publication_id, question_id, asker_id)
    #@TODO update engagement_type
    #@TODO create migration for new REP model
    unless correct.nil?
      self.update_attributes(:requires_action => false, :correct => correct)
      Stat.update_stat_cache("questions_answered", 1, asker_id, self.created_at, self.user_id)
      if self.posted_via_app
        Stat.update_stat_cache("internal_answers", 1, asker_id, self.created_at, self.user_id)
      else
        Stat.update_stat_cache("twitter_answers", 1, asker_id, self.created_at, self.user_id)
      end
    else
      self.update_attributes(:requires_action => false)
    end
    Stat.update_stat_cache("active_users", self.user_id, asker_id, self.created_at, self.user_id)
  end

  def self.twitter_request(&block)
    value = nil
    attempts = 0
    begin
      value = block.call()
    rescue Twitter::Error::ClientError => exception
      puts "twitter error (#{exception}), retrying"
      attempts += 1 
      retry unless attempts > 2
      puts "Failed to run #{block} after 3 attempts"
    rescue Exception => exception
      puts "Exception in twitter wrapper:"
      puts exception.message
    end 
    return value   
  end
  
  extend Split::Helper

  def self.trigger_split_test(user_id, test_name, reset=false)
    ab_user.set_id(user_id, true)
    finished(test_name, {:reset => reset})
  end
  
  def self.create_split_test(user_id, test_name, *alternatives)
    ab_user.set_id(user_id, true)
    ab_user.confirm_js("WISR app", '')
    ab_test(test_name, *alternatives)
  end
end
