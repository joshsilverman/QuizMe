class Post < ActiveRecord::Base
	belongs_to :question
	belongs_to :user
  belongs_to :publication
  belongs_to :conversation
	belongs_to :parent, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_one :child, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_many :conversations
	has_many :reps
  @@classifier = Classifier.new
  scope :not_spam, where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)

  ###
  ###Helper Methods
  ###

  #@TODO update helper methods to account for multiple engagement types

  def self.classifier
    @@classifier
  end

  def self.unanswered
    where(:responded_to => false)
  end

  ### Twitter
  def self.twitter_answers
    where("provider is 'twitter' and engagement_type like ?",'%answer%')
  end
  
  def self.twitter_nonanswer_mentions
    where("provider is 'twitter' and engagement_type like ?",'%nonanswer%')
  end

  def self.twitter_mentions
    where("provider is 'twitter' and engagement_type like ?",'%mention%')
  end

  def self.twitter_shares
    where("provider is 'twitter' and engagement_type like ?",'%share%')
  end

  def self.tweetable(text, user = "", url = "", hashtag = "", resource_url = "", via = "")
    user = "" if user.nil?
    url = "" if url.nil?
    via = "" if via.nil?
    if resource_url.blank?
      resource_url = "" 
    else
      resource_url = "Learn why at #{resource_url}" 
    end
    text_length = text.length
    handle_length = user.length
    url_length = url.length
    resource_url_length = resource_url.length
    hashtag_length = hashtag.nil? ? 0 : hashtag.length
    via_length = via.length
    remaining = 140
    remaining = (remaining - (handle_length + 2)) if handle_length > 0
    remaining = (remaining - (url_length + 1)) if url_length > 0
    remaining = (remaining - (hashtag_length + 2)) if hashtag_length > 0
    remaining = (remaining - (resource_url_length + 1)) if resource_url_length > 0
    remaining = (remaining - (via_length + 6)) if via_length > 0
    truncated_text = text[0..(remaining - 4)]
    truncated_text += "..." if text_length > remaining
    tweet = ""
    tweet += "@#{user} " if handle_length > 0
    tweet += "#{truncated_text}"
    tweet += " #{url}" if url_length > 0
    tweet += " #{resource_url}" if resource_url_length > 0
    tweet += " via @#{via}" if via_length > 0
    tweet += " ##{hashtag}" if hashtag_length > 0
    return tweet    
  end

  ### Facebook
  def self.facebook_answers
    where(:provider => 'facebook', :engagement_type => 'answer')
  end

  def self.facebook_shares
    where(:provider => 'facebook', :engagement_type => 'share')
  end

  ### Tumblr
  def self.tumblr_answers
    where(:provider => 'tumblr', :engagement_type => 'answer')
  end

  def self.tumblr_shares
    where(:provider => 'tumblr', :engagement_type => 'share')
  end

  ### Internal
  def self.internal_answers
    where(:posted_via_app => true, :engagement_type => 'answer')
  end

  def is_parent?
    self.publication_id? or self.in_reply_to_post_id.nil?
  end

  def sibling(provider)
    self.publication.posts.where(:provider => provider).first if self.publication_id
  end



	def self.shorten_url(url, source, lt, campaign, question_id=nil)
		authorize = UrlShortener::Authorize.new 'o_29ddlvmooi', 'R_4ec3c67bda1c95912185bc701667d197'
    shortener = UrlShortener::Client.new authorize
    short_url = shortener.shorten("#{url}?s=#{source}&lt=#{lt}&c=#{campaign}").urls
    short_url
	end

  ###
  ### Tweeting from the app
  ###

  def self.publish(provider, asker, publication)
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
        Post.tweet(
          asker, question.text, (ACCOUNT_DATA[asker.id] ? ACCOUNT_DATA[asker.id][:hashtags].sample : nil), 
          nil, long_url, 1, 
          'initial', nil, publication.id, 
          nil, nil, false, via, nil, nil
        )
        publication.update_attribute(:published, true)
        question.update_attribute(:priority, false) if question.priority
        if via.present? and question.priority
          Post.tweet(asker, "We thought you might like to know that your question was just published on #{asker.twi_screen_name}", "", via, long_url, 2, "ugc", nil, nil, nil, nil, false, nil, nil)
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

  def self.tweet(account, text, hashtag, reply_to, long_url, 
                 interaction_type, link_type, conversation_id,
                 publication_id, in_reply_to_post_id, 
                 in_reply_to_user_id, link_to_parent, via, resource_url, correct)
    return unless account.twitter_enabled?
    short_url = Post.shorten_url(long_url, 'twi', link_type, account.twi_screen_name) if long_url
    short_resource_url = Post.shorten_url(resource_url, 'twi', "res", account.twi_screen_name) if resource_url
    tweet = Post.tweetable(text, reply_to, short_url, hashtag, short_resource_url, via)
    if in_reply_to_post_id and link_to_parent
      parent_post = Post.find(in_reply_to_post_id) 
      twitter_response = account.twitter.update(tweet, {'in_reply_to_status_id' => parent_post.provider_post_id.to_i})
    else
      twitter_response = account.twitter.update(tweet)
    end
    post = Post.create(
      :user_id => account.id,
      :provider => 'twitter',
      :text => tweet,
      # :engagement_type => engagement_type,
      :provider_post_id => twitter_response.id.to_s,
      :in_reply_to_post_id => in_reply_to_post_id,
      :in_reply_to_user_id => in_reply_to_user_id,
      :conversation_id => conversation_id,
      :publication_id => publication_id,
      :url => long_url ? short_url : nil,
      :posted_via_app => true, 
      :responded_to => true,
      :interaction_type => interaction_type,
      :correct => correct
    )

    if publication_id
      publication = Publication.find(publication_id)
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
    user_post = Post.tweet(
      current_user, 
      answer.text, 
      '',
      asker.twi_screen_name,
      "#{URL}/feeds/#{asker.id}/#{publication_id}", 
      2, 
      status[0..2], 
      conversation.id, 
      nil, 
      post.id, 
      asker.id,
      false, 
      '',
      nil,
      answer.correct
    )
    if user_post
      conversation.posts << user_post
      user_post.update_responded(answer.correct, publication_id, publication.question_id, asker_id)
    end
    response_text = post.generate_response(status)
    publication.question.resource_url ? resource_url = "#{URL}/posts/#{post.id}/refer" : resource_url = nil
    app_post = Post.tweet(
      asker, 
      response_text, 
      '', 
      current_user.twi_screen_name,
      "#{URL}/feeds/#{asker.id}/#{publication_id}", 
      2, 
      status[0..2], 
      conversation.id, 
      nil, 
      (user_post ? user_post.id : nil), 
      current_user.id,
      true, 
      '',
      resource_url,
      nil
    )  
    conversation.posts << app_post if app_post
    return {:app_message => app_post.text, :user_message => user_post.text}
  end

  def self.dm(current_acct, tweet, long_url, lt, reply_post, user, conversation_id)
    short_url = Post.shorten_url(long_url, 'twi', lt, current_acct.twi_screen_name) if long_url
    res = current_acct.twitter.direct_message_create(user.twi_user_id, tweet)

    Post.create(
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
      :responded_to => true,
      :interaction_type => 4
    )
  end

  def self.dm_new_followers(current_acct)
    to_message = []
    new_followers = current_acct.twitter.follower_ids.ids.first(10)
    new_followers.each do |tid|
      u= User.find_by_twi_user_id(tid)
      if u.nil?
        new_u = User.create(:twi_user_id => tid)
        to_message.push new_u
      else
        unless current_acct.posts.where(:provider => 'twitter', :interaction_type => 4, :in_reply_to_user_id => u.id).count > 0
          to_message.push u
        end
      end
    end

    to_message.each do |user|
      dm = user.posts.where(:provider => 'twitter', :engagement_type => 'pm').last
      q = Question.find(current_acct.new_user_q_id) if current_acct.new_user_q_id
      Post.dm(current_acct, "Here's your first question! #{q.text}", nil, nil, dm.nil? ? nil : dm, user, nil)
    end
  end

  def self.create_tumblr_post(current_acct, text, url, lt, question_id, parent_id)
    #@TODO UPDATE POST METHOD
    short_url = Post.shorten_url(url, 'tum', lt, current_acct.twi_screen_name, question_id)
    res = current_acct.tumblr.text(current_acct.tum_url,
                                    :title => "Daily Quiz!",
                                    :body => "#{text} #{short_url}")
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
    return if post = Post.find_by_provider_post_id(m.id.to_s)
    puts m.in_reply_to_status_id.to_s
    reply_post = Post.find_by_provider_post_id(m.in_reply_to_status_id.to_s) if m.in_reply_to_status_id
    puts reply_post.to_json
    if reply_post and reply_post.is_parent?
      conversation = Conversation.create(
        :publication_id => reply_post.publication_id,
        :post_id => reply_post.id,
        :user_id => u.id
      )
    elsif reply_post and reply_post.conversation_id
      conversation = reply_post.conversation
    else
      puts "No reply post"
    end

    post = Post.create( 
      :provider_post_id => m.id.to_s,
      :engagement_type => reply_post ? 'mention reply' : 'mention',
      :text => m.text,
      :provider => 'twitter',
      :user_id => u.id,
      :in_reply_to_post_id => reply_post ? reply_post.id : nil,
      :in_reply_to_user_id => current_acct.id,
      :created_at => m.created_at,
      :conversation_id => conversation.nil? ? nil : conversation.id,
      :posted_via_app => false,
      :interaction_type => 2
    )
    Post.classifier.classify post
    Post.trigger_abingo_for_user(u.id, 'reengage')
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
        :interaction_type => 3
      )
      Post.trigger_abingo_for_user(u.id, 'reengage')
      Stat.update_stat_cache("retweets", 1, current_acct.id, post.created_at, u.id) unless u.role == "asker"
      Stat.update_stat_cache("active_users", u.id, current_acct.id, post.created_at, u.id) unless u.role == "asker"
    end
  end

  def self.save_dm_data(d, current_acct)
    u = User.find_or_create_by_twi_user_id(d.sender.id)
    u.update_attributes(:twi_name => d.sender.name,
                        :twi_screen_name => d.sender.screen_name,
                        :twi_profile_img_url => d.sender.profile_image_url)
    dm = Post.find_by_provider_post_id(d.id.to_s)
    return if dm
    reply_post = Post.where(:provider => 'twitter',
                            :interaction_type => 4,
                            :in_reply_to_user_id => u.id).last
    conversation_id = reply_post.nil? ? Conversation.create(:user_id => current_acct.id).id : reply_post.conversation_id

    post = Post.create( 
      :provider_post_id => d.id.to_s,
      :engagement_type => 'pm',
      :text => d.text,
      :provider => 'twitter',
      :user_id => u.id,
      :in_reply_to_post_id => nil, #reply_post ? reply_post.id : nil,
      :in_reply_to_user_id => current_acct.id,
      :created_at => d.created_at,
      :conversation_id => conversation_id,
      :posted_via_app => false,
      :interaction_type => 4
    )
    puts post.to_json
    Post.classifier.classify post
    Post.trigger_abingo_for_user(u.id, 'reengage')
    puts post.to_json
    puts "\n\n"
  end


  def generate_response(response_type)
    # puts "POST BRO:"
    # puts self.to_json
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
      # Rep.create(
      #   :user_id => self.user_id,
      #   :post_id => self.in_reply_to_post_id,
      #   :publication_id => publication_id,
      #   :question_id => question_id,
      #   :correct => correct
      # )
      self.update_attributes(:responded_to => true, :correct => correct)
      Stat.update_stat_cache("questions_answered", 1, asker_id, self.created_at, self.user_id)
      if self.posted_via_app
        Stat.update_stat_cache("internal_answers", 1, asker_id, self.created_at, self.user_id)
      else
        Stat.update_stat_cache("twitter_answers", 1, asker_id, self.created_at, self.user_id)
      end
    else
      self.update_attributes(:responded_to => true)
    end
    Stat.update_stat_cache("active_users", self.user_id, asker_id, self.created_at, self.user_id)
  end

  def self.trigger_abingo_for_user(user_id, test_name)
    puts "abingo_reengage"
    Abingo.identity = user_id
    puts "id = #{Abingo.identity}"
    puts "test = #{test_name}"
    res = Abingo.bingo! test_name
    puts "Response: #{res}"
    puts "end"
  end
end
