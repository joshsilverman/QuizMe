class Post < ActiveRecord::Base
  include EngagementEngine::Utils::Linker

	belongs_to :question
  belongs_to :in_reply_to_question, :class_name => 'Question', :foreign_key => 'in_reply_to_question_id'
  belongs_to :in_reply_to_user, :class_name => 'User', :foreign_key => 'in_reply_to_user_id'
  
  belongs_to :user
  has_and_belongs_to_many :tags, -> { uniq }
  belongs_to :asker, -> { where(role: 'asker') }, foreign_key: 'user_id'
  belongs_to :nudge_type

  belongs_to :publication
  belongs_to :conversation
  
  belongs_to :parent, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_one :child, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_many :conversations
  has_many :post_moderations

  scope :requires_action, -> { where('posts.requires_action = ?', true) }

  scope :not_spam, -> { where("((posts.interaction_type = 3 or posts.posted_via_app = ? or posts.correct is not null) or ((posts.autospam = ? and posts.spam is null) or posts.spam = ?))", true, false, false) }
  scope :spam, -> { where('posts.spam = ? or (posts.autospam = ? and posts.spam IS NULL)', true, true) }

  scope :not_us, -> { where('posts.user_id NOT IN (?)', (Asker.ids + ADMINS).empty? ? [0] : Asker.ids + ADMINS) }
  scope :not_asker, -> { where('posts.user_id NOT IN (?)', Asker.ids.empty? ? [0] : Asker.ids) }
  scope :us, -> { where('posts.user_id IN (?)', Asker.ids + ADMINS) }
  scope :social, -> { where('posts.interaction_type IN (2,3)') }

  scope :answers, -> { where('posts.correct is not null') }
  scope :correct_answers, -> { where('posts.correct = ?', true) }
  scope :incorrect_answers, -> { where('posts.correct = ?', false) }

  scope :ugc, -> { where("posts.id in (select post_id from posts_tags where posts_tags.tag_id = ?)", Tag.find_by_name('ugc')) }
  scope :not_ugc, -> { where("posts.id not in (select post_id from posts_tags where posts_tags.tag_id = ?)", Tag.find_by_name('ugc')) }
  scope :ugc_box, -> { requires_action.ugc }

  scope :friend, -> { where("posts.id in (select post_id from posts_tags where posts_tags.tag_id = ?)", Tag.find_by_name('ask a friend')) }
  scope :not_friend, -> { where("posts.id not in (select post_id from posts_tags where posts_tags.tag_id = ?)", Tag.find_by_name('ask a friend')) }

  scope :content, -> { where("posts.id in (select post_id from posts_tags where posts_tags.tag_id = ?)", Tag.find_by_name('new content')) }
  scope :not_content, -> { where("posts.id not in (select post_id from posts_tags where posts_tags.tag_id = ?)", Tag.find_by_name('new content')) }

  scope :moderated, -> { joins(:post_moderations).group('posts.id').having('count(moderations.id) > 2') } 
  scope :published, -> { includes(:in_reply_to_user).where("users.published = ?", true).references(:in_reply_to_user) }
  scope :autocorrected, -> { where("posts.autocorrect IS NOT NULL") }
  scope :not_autocorrected, -> { where("posts.autocorrect IS NULL") }
  scope :tagged, -> { joins(:tags).uniq }

  scope :grade, -> { where("posts.intention = ? or posts.intention = ?", 'grade', 'dm autoresponse') }

  scope :statuses, -> { where("posts.interaction_type = 1") }
  scope :mentions, -> { where("posts.interaction_type = 2") }
  scope :retweet, -> { where("posts.interaction_type = 3") }
  scope :not_retweet, -> { where("posts.interaction_type <> 3") }
  scope :dms, -> { where("posts.interaction_type = 4") }
  scope :not_dm, -> { where("posts.interaction_type <> 4") }
  scope :email, -> { where("posts.interaction_type = 5") }
  scope :apns, -> { where("posts.interaction_type = 6") }

  scope :reengage_inactive, -> { where("posts.intention = 'reengage inactive' or posts.is_reengagement = ?", true) }
  scope :followup, -> { where("posts.intention = 'incorrect answer followup'") }

  scope :linked, -> { where('posts.in_reply_to_question_id IS NOT NULL') }
  scope :unlinked, -> { where('posts.in_reply_to_question_id IS NULL') }

  scope :moderatable, -> { requires_action.linked.not_spam.not_retweet.published.not_ugc.not_content.not_friend }

  scope :nudge, -> { where("posts.nudge_type_id is not null") }

  scope :author_followup, -> { where("posts.intention = 'author followup'") }

  scope :moderated_by_admin, -> { where(moderation_trigger_type_id: nil) }
  scope :moderated_by_consensus, -> { where(moderation_trigger_type_id: 1) }
  scope :moderated_by_above_advanced, -> { where(moderation_trigger_type_id: 2) }
  scope :moderated_by_tiebreaker, -> { where(moderation_trigger_type_id: 3) }

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

  def is_spam?
    spam == true or autospam == true
  end

  def is_ugc?
    tags.include? Tag.find_by(name: "ugc")
  end

  def is_status?
    interaction_type == 1
  end

  def is_mention?
    interaction_type == 2
  end

  def is_retweet?
    interaction_type == 3
  end

  def is_dm?
    interaction_type == 4
  end

  def is_email?
    interaction_type == 5
  end

  def is_moderatable?
    return false unless correct.nil?
    return false if is_retweet?
    return false if is_spam?
    return false if posted_via_app
    return false if (Asker.ids + ADMINS).include?(user_id)
    return false if parent.try(:question_id).blank?
    true
  end

  def self.requires_moderations moderator
    moderator = moderator.becomes(Moderator)
    excluded_posts = PostModeration.where('created_at > ?', 30.days.ago)\
      .select(["post_id", "array_to_string(array_agg(type_id),',') as type_ids"]).group("post_id").to_a

    excluded_posts.reject! do |p|
      type_ids = p.type_ids.split ','
      if type_ids.count < 2
        true
      elsif (type_ids.count == 2 and type_ids.uniq.count == 2 and moderator.moderator_segment.present? and moderator.moderator_segment > 2)
        true
      end
    end

    excluded_post_ids = excluded_posts.collect(&:post_id)
    post_ids_moderated_by_current_user = moderator.post_moderations.collect(&:post_id)
    excluded_post_ids = (excluded_post_ids + post_ids_moderated_by_current_user).uniq
    excluded_post_ids = [0] if excluded_post_ids.empty?
    
    whitelisted_mod = WHITELISTED_MODERATORS.include?(moderator.id)
    follows_ids = moderator.follows.where("role = 'asker'").collect(&:id)
    follows_ids = Asker.published_ids if whitelisted_mod

    Post.includes(:in_reply_to_question => :answers).moderatable\
      .joins("INNER JOIN posts as parents on parents.id = posts.in_reply_to_post_id")\
      .where("parents.question_id IS NOT NULL")\
      .where("posts.in_reply_to_user_id IN (?)", follows_ids)\
      .where("posts.user_id <> ?", moderator.id)\
      .where("posts.id NOT IN (?)", excluded_post_ids)\
      .where('posts.created_at > ?', 30.days.ago)\
      .order('posts.created_at DESC').limit(10)\
      .references(:in_reply_to_question)\
      .sort_by{|p| p.created_at}.reverse    
  end


  def self.format_url(url, source, lt, campaign, target, show_answer = nil)
    return "#{url}?s=#{source}&lt=#{lt}&c=#{campaign}#{('&t=' + target) if target}#{'&ans=true' if show_answer}"
  end

  def self.publish(provider, asker, publication)
    return unless publication and question = publication.question
    via = ((question.user_id == 1 or question.user_id == asker.author_id) ? nil : question.user.twi_screen_name)
    long_url = "#{URL}/#{asker.subject_url}/#{publication.id}"
    case provider
    when "twitter"
      begin
        publication.update_attribute(:published, true)
        question_post = asker.send_public_message(question.text, {
          :hashtag => asker.hashtags.sample.try(:name), 
          :long_url => long_url, 
          :interaction_type => 1, 
          :link_type => 'initial', 
          :publication_id => publication.id, 
          :link_to_parent => false, 
          :via => via,
          :requires_action => false,
          :question_id => question.id
        })
        Rails.cache.delete "publications_recent_by_asker_#{asker.id}"
        
        if via.present? and question.priority
          text = "I just published a question you wrote! Retweet it here:"
          long_url = "https://twitter.com/intent/retweet?tweet_id=#{question_post.provider_post_id}"
          include_url = true

          asker.send_public_message(text, {
            :reply_to => via, 
            :long_url => include_url ? long_url : nil, 
            :interaction_type => 2, 
            :link_type => "ugc", 
            :link_to_parent => false,
            :in_reply_to_user_id => question.user_id,
            :intention => 'notify ugc'
          })        
        end
        question.update_attribute(:priority, false) if question.priority
      rescue Exception => exception
        puts "exception while publishing tweet"
        puts exception.message
      end
    end
  end

  def self.format_tweet(text, options = {})
    # set default ordering of text entities in tweet
    entity_order = [:in_reply_to_user, :text, :question_backlink, :hashtag, :resource_backlink]
    # set how each entity should be displayed
    formatting = {in_reply_to_user: "@{content}", 
      hashtag: "\#{content}", 
      resource_backlink: "Learn more at {content}"}

    # select entities in use for this tweet (always includes text)
    tweet_format = entity_order.select { |entity| entity == :text or options[entity].present? }
    # map over the array and replace with formatted text using provided entities
    tweet_format.map! { |entity| entity == :text ? entity : (formatting[entity].present? ? formatting[entity].gsub("{content}", options[entity]) : options[entity]) }
    # see how much space we have left for text 
    max_text_length = 140 - (tweet_format.sum { |entity| entity == :text ? 0 : entity.size } + tweet_format.size)

    #adjust max text length for backlinks which will be wrapped with t.co
    [:question_backlink, :resource_backlink, :url].each do |key|
      next unless options[key].present?
      max_text_length = max_text_length + options[key].length - TWI_SHORT_URL_LENGTH
    end

    # add answers if present and there's space
    text += " #{options[:answers]}" if (options[:answers].present? and (max_text_length - text.size) > (options[:answers].size + 1))
    tweet_format.map! { |entity| entity != :text ? entity : text.size > max_text_length ? "#{text[0..(max_text_length - 3)]}..." : text }.join " "
  end

  def self.collect_retweets asker
    retweets = Post.twitter_request { asker.twitter.retweets_of_me({:count => 10}) } || []
    retweets.each { |r| Post.save_retweet_data(r, asker) }
  end

  def self.check_for_posts current_acct
    client = current_acct.twitter

    # Get mentions, de-dupe, and save
    mentions = Post.twitter_request { client.mentions({:count => 200}) } || []
    existing_mention_ids = Post.select(:provider_post_id).where(:provider_post_id => mentions.collect { |m| m.id.to_s }).collect(&:provider_post_id)
    mentions.reject! { |m| existing_mention_ids.include? m.id.to_s }
    mentions.sort_by! { |m| m.created_at }
    mentions.each { |m| Post.save_mention_data(m, current_acct) }

    # Get DMs, de-dupe, and save
    dms = Post.twitter_request { client.direct_messages({:count => 200}) } || []
    existing_dm_ids = Post.select(:provider_post_id).where(:provider_post_id => dms.collect { |dm| dm.id.to_s }).collect(&:provider_post_id)
    dms.reject! { |d| existing_dm_ids.include? d.id.to_s }
    dms.sort_by! { |d| d.created_at }
    dms.each { |d| Post.save_dm_data(d, current_acct) }

    true 
  end

  def self.save_mention_data m, asker, conversation_id = nil
    u = User.find_or_initialize_by(twi_user_id: m.user.id)
    u.update_attributes(
      :twi_name => m.user.name,
      :name => m.user.name,
      :twi_screen_name => m.user.screen_name,
      :twi_profile_img_url => m.user.status.nil? ? nil : m.user.status.user.profile_image_url,
      :description => m.user.description.present? ? m.user.description : nil
    )

    in_reply_to_post = (m.in_reply_to_status_id ? Post.find_by(provider_post_id: m.in_reply_to_status_id.to_s) : nil)
    if in_reply_to_post
      if in_reply_to_post.is_question_post?
        conversation_id = Conversation.create(:publication_id => in_reply_to_post.publication_id, :post_id => in_reply_to_post.id, :user_id => u.id).id
      else
        conversation_id = in_reply_to_post.conversation_id || Conversation.create(:publication_id => in_reply_to_post.publication_id, :post_id => in_reply_to_post.id, :user_id => u.id).id
        in_reply_to_post.update_attribute :conversation_id, conversation_id
      end
      asker = in_reply_to_post.user.becomes(Asker) if asker.id != in_reply_to_post.user_id
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

    Post.classifier.classify post
    Post.grader.grade post
    
    asker.auto_respond(post.reload)
  end

  def self.save_dm_data d, asker
    u = User.find_or_initialize_by(twi_user_id: d.sender.id)
    u.update_attributes(
      twi_name: d.sender.name,
      name: d.sender.name,
      twi_screen_name: d.sender.screen_name,
      twi_profile_img_url: d.sender.profile_image_url,
      description: d.sender.description.present? ? d.sender.description : nil
    )

    in_reply_to_post = Post.where("provider = ? and interaction_type = 4 and ((user_id = ? and in_reply_to_user_id = ?) or (user_id = ? and in_reply_to_user_id = ?))", 'twitter', u.id, asker.id, asker.id, u.id)\
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
      :in_reply_to_user_id => asker.id,
      :created_at => d.created_at,
      :conversation_id => conversation_id,
      :posted_via_app => false,
      :interaction_type => 4,
      :requires_action => true
    )

    if (in_reply_to_post.try(:intention) == 'request email') and (email_address = post.extract_email_address)
      u.update(email: email_address)
      asker.send_private_message(u, 'Thanks!', {intention: "thank", in_reply_to_post_id: post.id})
      MP.track_event "added email address", { distinct_id: u.id }
    end

    u.update_user_interactions({
      :learner_level => "dm", 
      :last_interaction_at => post.created_at
    })

    Post.classifier.classify post
    Post.grader.grade post

    asker.auto_respond(post.reload)
  end

  def self.save_retweet_data(r, current_acct, attempts = 0)
    retweeted_post = Post.find_by(provider_post_id: r.id.to_s) || Post.create({:provider_post_id => r.id.to_s, :user_id => current_acct.id, :provider => "twitter", :text => r.text})    
    users = Post.twitter_request { current_acct.twitter.retweeters_of(r.id) } || []
    users.each do |user|
      u = User.find_or_initialize_by(twi_user_id: user.id)
      u.update_attributes( 
        :twi_name => user.name,
        :name => user.name,
        :twi_screen_name => user.screen_name,
        :twi_profile_img_url => user.profile_image_url,
        :description => user.description.present? ? user.description : nil
      )

      return if Post.where("user_id = ? and in_reply_to_post_id = ? and interaction_type = 3", u.id, retweeted_post.id).size > 0

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

      # puts "missed item in stream! RT: #{post.to_json}" if current_acct.id == 18
    end
  end

  def extract_email_address
    email_address = text.downcase.match(/[a-zA-Z0-9\_.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z0-9\-.]+/)
    return (email_address ? email_address.to_s : nil)
  end

  def self.save_post(interaction_type, tweet, asker_id, conversation_id = nil)
    # puts "saving post from stream (#{interaction_type}):"
    # puts "#{tweet.text} (ppid: #{tweet.id.to_s})"

    return if Post.find_by(provider_post_id: tweet.id.to_s)

    if interaction_type == 4
      twi_user = tweet.sender
      user = User.find_or_create_by(twi_user_id: tweet.sender.id.to_s)
      in_reply_to_post = Post.where("provider = ? and interaction_type = 4 and ((user_id = ? and in_reply_to_user_id = ?) or (user_id = ? and in_reply_to_user_id = ?))", 'twitter', asker_id, user.id, user.id, asker_id)\
        .order("created_at DESC")\
        .limit(1)\
        .first
      learner_level = "dm"
    else
      twi_user = tweet.user
      user = User.find_or_create_by(twi_user_id: tweet.user.id.to_s)
      if interaction_type == 2 
        in_reply_to_post = Post.find_by(provider_post_id: tweet.in_reply_to_status_id.to_s)
        learner_level = "mention"
      else
        in_reply_to_post = Post.find_by(provider_post_id: tweet.retweeted_status.id.to_s)
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

  # Note: when passing text to twi 'update' method, must pass var, not raw str. May only pass single quote strs.
  def self.twitter_request(failure_message = nil, &block)
    return [] if Rails.env.test?

    source_line = block.to_source(:strip_enclosure => true)
    return [] unless Post.is_safe_api_call?(source_line)
    
    value = nil
    max_attempts = 3
    attempts = 0
    begin
      attempts += 1
      value = block.call()
    rescue Twitter::Error::TooManyRequests => exception
      puts "Twitter Error: rate limit exceeded on line '#{source_line}':"
      puts exception.rate_limit.inspect
      raise "Rate limit exceeded"
    rescue Twitter::Error => exception
      unless attempts >= max_attempts \
        or exception.message.include? "Status is a duplicate" \
        or exception.message.include? "Bad Authentication data" \
        or exception.message.include? "Could not authenticate you" \
        or exception.message.include? "Your account is suspended" \
        or exception.message.include? "that page does not exist" \
        or exception.message.include? "execution expired" \
        or exception.message.include? "You cannot send messages to users who are not following you" \
        or exception.message.include? "Not authorized"

        puts "Twitter Error: (#{exception}), retrying: #{failure_message}"
        retry
      else
        puts "Twitter Error: (#{exception}): #{failure_message}"
      end
      puts "Failed to run #{block} ('#{source_line}') after #{attempts} attempts: #{failure_message}"
    rescue Exception => exception
      puts "Twitter Error (#{exception}) with message: #{failure_message}"
    end
    return value   
  end

  def self.is_safe_api_call?(block)
    return true if Rails.env.production?
    TWI_DEV_SAFE_API_CALLS.each { |allowed_call| return true if block.include? ".#{allowed_call}" }
    return false
  end
 
  def self.grouped_as_conversations posts, asker = nil, engagements = {}, conversations = {}, dm_ids = []
    return {}, {} if posts.blank?

    posts.each do |post|
      engagements[post.id] = post
      conversations[post.id] = {:posts => [], :answers => [], :users => {}}
      conversations[post.id][:users][post.user.id] = post.user      
      parent_publication = nil
      if post.interaction_type == 4
        if asker.nil?
          asker_id = post.in_reply_to_user_id
        else
          asker_id = asker.id
        end

        dm_history = Post.where("interaction_type = 4 and ((user_id = ? and in_reply_to_user_id = ?) or (user_id = ? and in_reply_to_user_id = ?))", asker_id, post.user_id, post.user_id, asker_id).includes(:user).order("created_at DESC")
        dm_history.each do |dm|
          conversations[post.id][:posts] << dm
          conversations[post.id][:users][dm.user.id] = dm.user if conversations[post.id][:users][dm.user.id].nil?
          dm_ids << dm.id
        end
      else
        if post.conversation.present?
          # post.conversation.posts.where("user_id = ? or user_id = ?", post.user_id, post.in_reply_to_user_id).order("created_at DESC").each do |conversation_post|
          post.conversation.posts.order("created_at DESC").each do |conversation_post|
            conversations[post.id][:posts] << conversation_post
            conversations[post.id][:users][conversation_post.user.id] = conversation_post.user if conversations[post.id][:users][conversation_post.user.id].nil?
          end
          parent_publication = post.conversation.publication
          if post.conversation.post.is_question_post?
            conversations[post.id][:posts] << post.conversation.post
            conversations[post.id][:users][post.conversation.post.user.id] = post.conversation.post.user if conversations[post.id][:users][post.conversation.post.user.id].nil?
          end
        else
          conversations[post.id][:posts] << post
        end
      end
      post.text = post.parent.text if post.interaction_type == 3
      conversations[post.id][:answers] = parent_publication.question.answers unless parent_publication.nil?      
    end

    return engagements, conversations
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

  def is_question_post?
    interaction_type == 1 and publication_id.present?
  end

  def send_to_stream
    Pusher['stream'].trigger('answer', {
        "created_at" => created_at,
        "in_reply_to_question" => {
          "id" => in_reply_to_question.id,
          "text" => in_reply_to_question.text
          },
        "user" => {
          "twi_screen_name" => user.twi_screen_name,
          "twi_profile_img_url" => user.twi_profile_img_url
        }
      })
  end

  def send_to_publication
    publication = Publication.published
      .where(question_id: in_reply_to_question_id)
      .order(created_at: :desc).first
    return if publication.nil?

    publication.update_activity self
    publication
  end
end
