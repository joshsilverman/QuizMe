class Post < ActiveRecord::Base
	belongs_to :question
	belongs_to :user
  belongs_to :publication
  belongs_to :conversation
	belongs_to :parent, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_one :child, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_many :conversations
	has_many :reps
  scope :not_spam, where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)
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
    return unless publication
    question = Question.find(publication.question_id)
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
      twitter_response = user.twitter.update(tweet, {'in_reply_to_status_id' => parent_post.provider_post_id.to_i})
    else
      twitter_response = user.twitter.update(tweet)
    end  
    post = Post.create(
      :user_id => user.id,
      :provider => 'twitter',
      :text => tweet,
      :provider_post_id => twitter_response.id.to_s,
      :in_reply_to_post_id => options[:in_reply_to_post_id],
      :in_reply_to_user_id => options[:in_reply_to_user_id],
      :conversation_id => options[:conversation_id],
      :publication_id => options[:publication_id],
      :url => options[:long_url] ? short_url : nil,
      :posted_via_app => true, 
      :requires_action => false,
      :interaction_type => options[:interaction_type],
      :correct => options[:correct],
      :intention => options[:intention]
    )   
    if options[:publication_id]
      publication = Publication.find(options[:publication_id])
      publication.posts << post
    end
    return post        
  end

  def self.app_response(current_user, asker_id, publication_id, answer_id)
    asker = User.asker(asker_id)
    publication = Publication.find(publication_id)
    answer = Answer.select([:text, :correct]).find(answer_id)
    status = (answer.correct ? "correct" : "incorrect")
    post = publication.posts.where(:provider => "twitter").first
    conversation = Conversation.find_or_create_by_user_id_and_post_id_and_publication_id(current_user.id, post.id, publication_id) 
    user_post = Post.tweet(current_user, answer.text, {
      :reply_to => asker.twi_screen_name,
      :long_url => "#{URL}/feeds/#{asker.id}/#{publication_id}", 
      :interaction_type => 2, 
      :link_type => status[0..2], 
      :conversation_id => conversation.id, 
      :in_reply_to_post_id => post.id, 
      :in_reply_to_user_id => asker.id,
      :link_to_parent => false, 
      :correct => answer.correct
    })
    if user_post
      conversation.posts << user_post
      user_post.update_responded(answer.correct, publication_id, publication.question_id, asker_id)
    end
    Post.trigger_split_test(current_user.id, 'dm reengagement')
    response_text = post.generate_response(status)
    publication.question.resource_url ? resource_url = "#{URL}/posts/#{post.id}/refer" : resource_url = "#{URL}/questions/#{publication.question_id}/#{publication.question.slug}"
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
      :wisr_question => publication.question.resource_url ? false : true
    })  
    conversation.posts << app_post if app_post

    #check for follow-up test completion
    if Post.joins(:conversation).where("posts.intention = ? and posts.in_reply_to_user_id = ? and conversations.publication_id = ?", 'incorrect answer follow up', current_user.id, publication_id).present?
      Post.trigger_split_test(current_user.id, 'mention reengagement') 
      Mixpanel.track_event "answered incorrect follow up", {
        :distinct_id => current_user.id,
        :account => asker.twi_screen_name,
      }
    end
    #check for re-engage inactive test completion
    Post.trigger_split_test(current_user.id, 'reengage last week inactive') if Post.where("in_reply_to_user_id = ? and intention = ?", current_user.id, 'reengage last week inactive').present?    

    Mixpanel.track_event "answered", {
      :distinct_id => current_user.id,
      :account => asker.twi_screen_name,
      :source => "twi"
    }
    return {:app_message => app_post.text, :user_message => user_post.text}
  end

  def self.dm(current_acct, tweet, long_url, lt, reply_post, user, conversation_id)
    short_url = Post.shorten_url(long_url, 'twi', lt, current_acct.twi_screen_name) if long_url
    begin
      res = current_acct.twitter.direct_message_create(user.twi_user_id, tweet)
      dm = Post.create(
        :user_id => current_acct.id,
        :provider => 'twitter',
        :text => tweet,
        :engagement_type => 'pm',
        :provider_post_id => res.id.to_s,
        :in_reply_to_post_id => reply_post.nil? ? nil : reply_post.id,
        :in_reply_to_user_id => user.id,
        :conversation_id => conversation_id,
        :url => long_url ? short_url : nil,
        :posted_via_app => true,
        :requires_action => false,
        :interaction_type => 4
      )
    rescue Exception => exception
      puts "exception in DM user"
      puts exception.message
    end    
    return dm
  end

  def self.dm_new_followers(current_acct)
    to_message = []
    new_followers = current_acct.twitter.follower_ids.ids.first(10)
    new_followers.each do |tid|
      user = User.find_by_twi_user_id(tid)
      if user.nil?
        user = User.create(:twi_user_id => tid)
        to_message.push user
      else
        unless current_acct.posts.where(:provider => 'twitter', :interaction_type => 4, :in_reply_to_user_id => user.id).count > 0
          to_message.push user
        end
      end
      current_acct.twitter.follow(tid)
    end

    to_message.each do |user|
      dm = user.posts.where(:provider => 'twitter', :engagement_type => 'pm').last
      q = Question.find(current_acct.new_user_q_id) if current_acct.new_user_q_id
      Post.dm(current_acct, "Here's your first question! #{q.text}", nil, nil, dm.nil? ? nil : dm, user, nil)
      Mixpanel.track_event "DM question to new follower", {
        :distinct_id => user.id,
        :account => current_acct.twi_screen_name
      }
      sleep(2)
    end
  end

  def self.create_tumblr_post(current_acct, text, url, lt, question_id, parent_id)
    #@TODO UPDATE POST METHOD
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
    return unless current_acct.twitter_enabled?
    asker_ids = User.askers.collect(&:id)
    last_post = Post.where("provider like ? and provider_post_id is not null and user_id not in (?) and posted_via_app = ?", 'twitter', asker_ids, false,).order('created_at DESC').limit(1).last
    last_dm = Post.where("provider like ? and provider_post_id is not null and user_id not in (?) and posted_via_app = ?", 'twitter', asker_ids, false).order('created_at DESC').limit(1).last
    client = current_acct.twitter
    mentions = client.mentions({:count => 50, :since_id => last_post.nil? ? nil : last_post.provider_post_id.to_i})
    retweets = client.retweets_of_me({:count => 50})
    dms = client.direct_messages({:count => 50, :since_id => last_dm.nil? ? nil : last_dm.provider_post_id.to_i})
    mentions.each { |m| Post.save_mention_data(m, current_acct) }
    retweets.each { |r| Post.save_retweet_data(r, current_acct) }
    dms.each { |d| Post.save_dm_data(d, current_acct) }
    true
  end

  def self.save_mention_data(m, current_acct)
    u = User.find_or_create_by_twi_user_id(m.user.id)
    u.update_attributes(
      :twi_name => m.user.name,
      :twi_screen_name => m.user.screen_name,
      :twi_profile_img_url => m.user.status.nil? ? nil : m.user.status.user.profile_image_url
    )

    return if Post.find_by_provider_post_id(m.id.to_s)

    in_reply_to_post = Post.find_by_provider_post_id(m.in_reply_to_status_id.to_s) if m.in_reply_to_status_id
    if in_reply_to_post
      conversation_id = in_reply_to_post.conversation_id || Conversation.create(:publication_id => in_reply_to_post.publication_id,:post_id => in_reply_to_post.id,:user_id => u.id).id
    else
      conversation_id = nil
      puts "No in reply to post"
    end
    puts m.text

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

    Post.classifier.classify post
    Post.trigger_split_test(u.id, 'dm reengagement')
    Stat.update_stat_cache("mentions", 1, current_acct.id, post.created_at, u.id) unless u.role == "asker"
    Stat.update_stat_cache("active_users", u.id, current_acct.id, post.created_at, u.id) unless u.role == "asker"
  end

  def self.save_retweet_data(r, current_acct, attempts = 0)
    retweeted_post = Post.find_by_provider_post_id(r.id.to_s) || Post.create({:provider_post_id => r.id.to_s, :user_id => current_acct.id, :provider => "twitter", :text => r.text})    
    begin
      users = current_acct.twitter.retweeters_of(r.id)  
    rescue Twitter::Error::ClientError 
      attempts += 1 
      retry unless attempts > 2
      puts "Failed after three attempts"
      users = []
    rescue Exception => exception
      puts "exception while getting retweeters_of"
      puts exception.message
      users = []
    end

    users.each do |user|
      u = User.find_or_create_by_twi_user_id(user.id)
      u.update_attributes(
        :twi_name => user.name,
        :twi_screen_name => user.screen_name,
        :twi_profile_img_url => user.profile_image_url
      )
      post = Post.where("user_id = ? and in_reply_to_post_id = ? and interaction_type = 3", u.id, retweeted_post.id).first
      return if post
      post = Post.create(
        :engagement_type => 'share',
        :provider => 'twitter',
        :user_id => u.id,
        :in_reply_to_post_id => retweeted_post.id,
        :in_reply_to_user_id => retweeted_post.user_id,
        :posted_via_app => false,
        :created_at => r.created_at,
        :interaction_type => 3,
        :requires_action => true
      )
      Post.trigger_split_test(u.id, 'dm reengagement')
      Stat.update_stat_cache("retweets", 1, current_acct.id, post.created_at, u.id) unless u.role == "asker"
      Stat.update_stat_cache("active_users", u.id, current_acct.id, post.created_at, u.id) unless u.role == "asker"
    end
  end

  def self.save_dm_data(d, current_acct)
    u = User.find_or_create_by_twi_user_id(d.sender.id)
    u.update_attributes(
      :twi_name => d.sender.name,
      :twi_screen_name => d.sender.screen_name,
      :twi_profile_img_url => d.sender.profile_image_url
    )
    
    return if Post.find_by_provider_post_id(d.id.to_s)

    in_reply_to_post = Post.where(
      :provider => 'twitter',
      :interaction_type => 4,
      :user_id => u.id
    ).order("created_at DESC").limit(1).first

    if in_reply_to_post
      conversation_id = in_reply_to_post.conversation_id || Conversation.create(:post_id => in_reply_to_post.id, :user_id => u.id).id
    else
      conversation_id = nil
      puts "No in reply to dm"
    end

    puts d.text
    # any issue w/ origin dm and its response being collected 
    # in same rake, then being created in the wrong order?
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
    Post.trigger_split_test(u.id, 'dm reengagement')
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

  extend Split::Helper
  def self.trigger_split_test(user_id, test_name, reset=false)
    ab_user.set_id(user_id, true)
    finished(test_name, {:reset => reset})
  end
  
  def self.create_split_test(user_id, test_name, a, b)
    ab_user.set_id(user_id, true)
    ab_user.confirm_js("WISR app", '')
    ab_test(test_name, a, b)
  end
end
