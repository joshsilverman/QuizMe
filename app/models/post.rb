class Post < ActiveRecord::Base
	belongs_to :question
	belongs_to :user
  has_and_belongs_to_many :tags, :uniq => true
  belongs_to :asker, :foreign_key => 'user_id', :conditions => { :role => 'asker' }
  # has_many :comments, :conditions => { :published => true }
  # belongs_to :asker, :class_name => "User", :foreign_key => 'asker_id'

  belongs_to :publication
  belongs_to :conversation
	belongs_to :parent, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_one :child, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_many :conversations
	has_many :reps

  scope :requires_action, where('posts.requires_action = ?', true)

  scope :not_spam, where("((posts.interaction_type = 3 or posts.posted_via_app = ? or posts.correct is not null) or ((posts.autospam = ? and posts.spam is null) or posts.spam = ?))", true, false, false)
  scope :spam, where('posts.spam = ? or posts.autospam = ?', true, true)

  scope :not_us, where('posts.user_id NOT IN (?)', Asker.ids + ADMINS)
  scope :social, where('interaction_type IN (2,3)')
  scope :answers, where('correct IS NOT NULL')

  scope :ugc, includes(:tags).where(:tags => {:name => 'ugc'})
  scope :not_ugc, includes(:tags).where('tags.name <> ? or tags.name IS NULL', 'ugc')

  scope :autocorrected, where("posts.autocorrect IS NOT NULL")
  scope :not_autocorrected, where("posts.autocorrect IS NULL")

  scope :statuses, where('interaction_type = 1')
  scope :not_retweet, where("posts.interaction_type <> 3")
  scope :retweet, where(:interaction_type => 3)
  scope :mentions, where("posts.interaction_type = 2")
  scope :dms, where("posts.interaction_type = 4")

  scope :linked, includes(:conversation => {:publication => :question, :post => {:asker => :new_user_question}}).where("questions.id IS NOT NULL")
  scope :unlinked, includes(:conversation => {:publication => :question, :post => {:asker => :new_user_question}}).where("questions.id IS NULL")

  scope :retweet_box, requires_action.retweet.not_ugc
  scope :spam_box, requires_action.spam.not_ugc
  scope :ugc_box, ugc
  scope :linked_box, requires_action.not_autocorrected.linked.not_ugc.not_spam.not_retweet
  scope :unlinked_box, requires_action.not_autocorrected.unlinked.not_ugc.not_spam.not_retweet
  scope :all_box, requires_action.not_spam.not_retweet
  scope :autocorrected_box, includes(:user, :conversation => {:publication => :question, :post => {:asker => :new_user_question}}, :parent => {:publication => :question}).requires_action.not_ugc.not_spam.not_retweet.autocorrected

  def self.answers_count
    Rails.cache.fetch 'posts_answers_count', :expires_in => 5.minutes do
      Post.where("correct is not null").count
    end
  end

  def self.ugc_post_counts
    Post.ugc_box.group('in_reply_to_user_id').count
  end  

  def self.classifier
    @@_classifier ||= Classifier.new
  end

  def self.grader
    @@_grader ||= Grader.new
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
    if Rails.env.production?
      return Shortener.shorten("#{url}?s=#{source}&lt=#{lt}&c=#{campaign}#{'&ans=true' if show_answer}").short_url
    else
      return "http://wisr.co/devurl"
    end
  end

  def self.publish(provider, asker, publication)
    return unless publication and question = publication.question
    via = (question.user_id == 1 ? nil : question.user.twi_screen_name)
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
          :via => via,
          :requires_action => false
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

  def self.tweet(sender, text, options = {}, post = nil)
    short_url = Post.shorten_url(options[:long_url], 'twi', options[:link_type], sender.twi_screen_name) if options[:long_url]
    short_resource_url = Post.shorten_url(options[:resource_url], 'twi', "res", sender.twi_screen_name, options[:wisr_question]) if options[:resource_url]
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
      twitter_response = Post.twitter_request { sender.twitter.update(tweet, {'in_reply_to_status_id' => parent_post.provider_post_id.to_i}) }
    else
      twitter_response = Post.twitter_request { sender.twitter.update(tweet) }
    end
    if twitter_response
      options[:in_reply_to_user_id] = [options[:in_reply_to_user_id]] unless options[:in_reply_to_user_id].is_a?(Array)
      options[:in_reply_to_user_id].each do |user_id|
        post = Post.create(
          :user_id => sender.id,
          :provider => 'twitter',
          :text => tweet,
          :provider_post_id => twitter_response.present? ? twitter_response.id.to_s : 0,
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

  def self.dm(sender, recipient, text, options = {})    
    short_url = Post.shorten_url(options[:long_url], 'twi', options[:link_type], sender.twi_screen_name) if options[:long_url]
    text = "#{text} #{short_url}" if options[:include_url] and short_url
    begin
      res = Post.twitter_request { sender.twitter.direct_message_create(recipient.twi_user_id, text) }
      post = Post.create(
        :user_id => sender.id,
        :provider => 'twitter',
        :text => text,
        :provider_post_id => res.present? ? res.id.to_s : 0,
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

  def self.check_for_posts(current_acct)
    client = current_acct.twitter

    # Get mentions, de-dupe, and save
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

  def self.save_mention_data(m, asker)
    u = User.find_or_create_by_twi_user_id(m.user.id)
    u.update_attributes(
      :twi_name => m.user.name,
      :twi_screen_name => m.user.screen_name,
      :twi_profile_img_url => m.user.status.nil? ? nil : m.user.status.user.profile_image_url
    )

    conversation_id = nil
    
    in_reply_to_post = Post.find_by_provider_post_id(m.in_reply_to_status_id.to_s) if m.in_reply_to_status_id
    if in_reply_to_post
      conversation_id = in_reply_to_post.conversation_id || Conversation.create(:publication_id => in_reply_to_post.publication_id, :post_id => in_reply_to_post.id, :user_id => u.id).id
      in_reply_to_post.update_attribute(:conversation_id, conversation_id)
    end

    post = Post.create( 
      :provider_post_id => m.id.to_s,
      :text => m.text,
      :provider => 'twitter',
      :user_id => u.id,
      :in_reply_to_post_id => in_reply_to_post.try(:id),
      :in_reply_to_user_id => asker.id,
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

    puts "missed item in stream! mention: #{post.to_json}" if asker.id == 18

    Post.classifier.classify post
    Post.grader.grade post
    
    asker.auto_respond(post.reload)

    Stat.update_stat_cache("mentions", 1, asker.id, post.created_at, u.id) unless u.role == "asker"
    Stat.update_stat_cache("active_users", u.id, asker.id, post.created_at, u.id) unless u.role == "asker"
  end

  def self.save_dm_data(d, current_acct)
    u = User.find_or_create_by_twi_user_id(d.sender.id)
    u.update_attributes(
      :twi_name => d.sender.name,
      :twi_screen_name => d.sender.screen_name,
      :twi_profile_img_url => d.sender.profile_image_url
    )

    in_reply_to_post = Post.where("provider = ? and interaction_type = 4 and ((user_id = ? and in_reply_to_user_id = ?) or (user_id = ? and in_reply_to_user_id = ?))", 'twitter', u.id, current_acct.id, current_acct.id, u.id)\
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

    puts "missed item in stream! DM: #{post.to_json}" if current_acct.id == 18

    Post.classifier.classify post
    Post.grader.grade post
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
        # :provider_post_id => r.id.to_s,
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

      puts "missed item in stream! RT: #{post.to_json}" if current_acct.id == 18

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
      in_reply_to_post = Post.where("provider = ? and interaction_type = 4 and ((user_id = ? and in_reply_to_user_id = ?) or (user_id = ? and in_reply_to_user_id = ?))", 'twitter', asker_id, user.id, user.id, asker_id)\
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
    Post.grader.grade post
  end

  def self.twitter_request(&block)
    return [] unless Post.is_safe_api_call?(block.to_source(:strip_enclosure => true))
    value = nil
    attempts = 0
    begin
      value = block.call()
    rescue Twitter::Error::ClientError => exception
      puts "twitter error (#{exception}), retrying"
      attempts += 1 
      retry unless attempts > 2 or exception.message == "Status is a duplicate."
      puts "Failed to run #{block} after #{attempts} attempts"
    rescue Exception => exception
      puts "Exception in twitter wrapper: #{exception.message}"
    end 
    return value   
  end
  
  extend Split::Helper

  def self.is_safe_api_call?(block)
    return true if Rails.env.production?
    TWI_DEV_SAFE_API_CALLS.each { |allowed_call| return true if block.include? ".#{allowed_call}" }
    return false
  end

  def self.trigger_split_test(user_id, test_name, reset=false)
    ab_user.set_id(user_id, true)
    finished(test_name, {:reset => reset})
  end
  
  def self.create_split_test(user_id, test_name, *alternatives)
    ab_user.set_id(user_id, true)
    ab_user.confirm_js("WISR app", '')
    ab_test(test_name, *alternatives)
  end

  def self.grouped_as_conversations posts, asker
    return {}, {} if posts.empty?

    @_posts = {}
    @conversations = {}
    dm_ids = []
    posts.each do |p|
      next if dm_ids.include? p.id
      @_posts[p.id] = p
      @conversations[p.id] = {:posts => [], :answers => [], :users => {}}
      @conversations[p.id][:users][p.user.id] = p.user
      parent_publication = nil
      if p.interaction_type == 4
        dm_history = Post.where("id != ? and interaction_type = 4 and ((user_id = ? and in_reply_to_user_id = ?) or (user_id = ? and in_reply_to_user_id = ?))", p.id, asker.id, p.user_id, p.user_id, asker.id).order("created_at DESC")
        dm_history.each do |dm|
          next if dm.id == p.id
          @conversations[p.id][:posts] << dm
          @conversations[p.id][:users][dm.user.id] = dm.user if @conversations[p.id][:users][dm.user.id].nil?
          dm_ids << dm.id
        end
      else  
        parent = p.parent  
        while parent
          if parent.in_reply_to_user_id == asker.id or parent.user_id == asker.id
            @conversations[p.id][:posts] << parent
            @conversations[p.id][:users][parent.user.id] = parent.user if @conversations[p.id][:users][parent.user.id].nil?
            parent_publication = parent.publication unless parent.publication.nil?
          end
          parent = parent.parent
        end
      end
      p.text = p.parent.text if p.interaction_type == 3
      @conversations[p.id][:answers] = parent_publication.question.answers unless parent_publication.nil?
    end

    return @_posts, @conversations
  end

  def self.recent_activity_on_posts(posts, actions, action_hash = {}, post_pub_map = {})
    posts.each { |post| post_pub_map[post.id] = post.publication_id }
    actions.each do |post_id, post_activity|
      action_hash[post_pub_map[post_id]] ||= []
      post_activity.each do |action|
        action_hash[post_pub_map[post_id]] << {
          :user => {
            :id => action.user.id,
            :twi_screen_name => action.user.twi_screen_name,
            :twi_profile_img_url => action.user.twi_profile_img_url
          },
          :interaction_type => action.interaction_type, 
        } unless action_hash[post_pub_map[post_id]].nil?
      end
      action_hash[post_pub_map[post_id]].uniq!{|a|a[:user][:id]}
    end  
    action_hash
  end

  def clean_text
    return '' if text.nil?

    # hashtags and handles
    _text = text.gsub /(:?@|#)[^\s]+/, ''

    # url
    _text.gsub! /http:\/\/[^\s]+/, ''

    # punctuation
    _text.gsub! /!+/, ''
    _text.gsub! /(?::|;|=)(?:-)?(?:\)|D|P)/, ''

    #remove RTs
    _text.gsub! /RT .+/, ''

    # whitespace
    _text.gsub! /[\s]+/, ' '
    _text.strip!

    _text
  end

  def in_answer_to_question
    @_in_answer_to_question = nil

    if @_in_answer_to_question
      # already have question in memory
    elsif interaction_type == 3
      # retweet
    elsif interaction_type == 4 and conversation and conversation.post and conversation.post.user and conversation.post.user.is_role? "asker"
      asker = Asker.find(conversation.post.user_id)
      @_in_answer_to_question = Question.includes(:answers => nil, :publications => {:conversations => :posts}).find(asker.new_user_q_id)
    elsif conversation and conversation.publication and conversation.publication.question
      @_in_answer_to_question = conversation.publication.question
    elsif parent and parent.publication and parent.publication.question
      @_in_answer_to_question = parent.publication.question
    end

    @_in_answer_to_question
  end

end
