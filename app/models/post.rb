class Post < ActiveRecord::Base
	belongs_to :question
	belongs_to :user
  belongs_to :publication
  belongs_to :conversation
	belongs_to :parent, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_one :child, :class_name => 'Post', :foreign_key => 'in_reply_to_post_id'
  has_many :conversations
	has_many :reps

  #URL = "http://studyegg-quizme-staging.herokuapp.com"

  ###
  ###Helper Methods
  ###

  #@TODO update helper methods to account for multiple engagement types

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

  def self.tweetable(text, user = "", url = "")
    user = "" if user.nil?
    url = "" if url.nil?
    text_length = text.length
    handle_length = user.length
    url_length = url.length
    remaining = 140
    remaining = (remaining - (handle_length + 2)) if handle_length > 0
    remaining = (remaining - (url_length + 1)) if url_length > 0
    truncated_text = text[0..(remaining - 4)]
    truncated_text += "..." if text_length > remaining
    tweet = ""
    tweet += "@#{user} " if handle_length > 0
    tweet += "#{truncated_text}"
    tweet += " #{url}" if url_length > 0
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
  def is_parent?
    self.publication_id? or self.in_reply_to_post_id.nil?
  end

  def sibling(provider)
    if self.publication_id
      #@TODO find publication and return child by provider
    end
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
    long_url = "#{URL}/feeds/#{asker.id}/#{publication.id}"
    puts long_url
    case provider
    when "twitter"
      Post.tweet(asker, question.text, nil, long_url, 
                 'status question', 'initial', nil,
                 publication.id, nil, nil)
    when "tumblr"
      puts "No Tumblr Post Methods"
    when "facebook"
      puts "No Tumblr Post Methods"
    else  
      puts "Boo"
    end
  end

  def self.tweet(account, tweet, reply_to, long_url, 
                 engagement_type, link_type, conversation_id,
                 publication_id, in_reply_to_post_id, 
                 in_reply_to_user_id)
    return unless account.twitter_enabled?
    short_url = Post.shorten_url(long_url, 'twi', link_type, account.twi_screen_name) if long_url
    if in_reply_to_post_id
      parent_post = Post.find(in_reply_to_post_id) 
      response = account.twitter.update("#{Post.tweetable(tweet, reply_to, short_url)}", {'in_reply_to_status_id' => parent_post.provider_post_id.to_i})
    else
      response = account.twitter.update("#{Post.tweetable(tweet, reply_to, short_url)}")
    end
    post = Post.create(
      :user_id => account.id,
      :provider => 'twitter',
      :text => tweet,
      :engagement_type => engagement_type,
      :provider_post_id => response.id.to_s,
      :in_reply_to_post_id => in_reply_to_post_id,
      :in_reply_to_user_id => in_reply_to_user_id,
      :conversation_id => conversation_id,
      :publication_id => publication_id,
      :posted_via_app => true
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
      asker.twi_screen_name,
      "#{URL}/feeds/#{asker.id}/#{publication_id}", 
      "reply answer #{status}", 
      status[0..2], 
      conversation.id, 
      nil, 
      post.id, 
      asker.id
    )
    conversation.posts << user_post
    user_post.respond(answer.correct, publication_id, publication.question_id, asker_id)
    response = post.generate_response(status)
    app_post = Post.tweet(
      asker, 
      response, 
      current_user.twi_screen_name,
      "#{URL}/feeds/#{asker.id}/#{publication_id}", 
      "reply answer_response #{status}", 
      status[0..2], 
      conversation.id, 
      nil, 
      user_post.id, 
      current_user.id
    )  
    conversation.posts << app_post
    return {:message => response, :url => publication.url}
  end

  def self.dm(current_acct, tweet, url, lt, question_id, user_id)
    #UPDATE POST METHOD
    short_url = Post.shorten_url(url, 'twi', lt, current_acct.twi_screen_name, question_id) if url
    res = current_acct.twitter.direct_message_create(user_id, "#{tweet} #{short_url if short_url}")
    Post.create(
      :asker_id => current_acct.id,
      :question_id => question_id,
      :to_twi_user_id => user_id,
      :provider => 'twitter',
      :text => tweet,
      :url => url.nil? ? nil : short_url,
      :link_type => lt,
      :post_type => 'dm',
      :provider_post_id => res.id.to_s
    )
  end

  def self.dm_new_followers(current_acct)
    #@TODO update url and make dynamic for each asker account
    new_followers = current_acct.twitter.follower_ids.ids.first(10).to_set
    messaged = current_acct.posts.where(:provider => 'twitter',
                            :post_type => 'dm').collect(&:to_twi_user_id).to_set
    to_message = new_followers - messaged

    to_message.each do |id|
      Post.dm(current_acct,
              "Here's your first question: How many base pairs make a codon? ", 
              "http://www.studyegg.com/review/112/10187", 
              "dm",
              21,
              id)
      sleep(1)
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
      :parent_id => parent_id
    )
  end


  ###
  ### Getting and Setting Posts retrieved from Twitter
  ###

  def self.check_for_posts(current_acct)
    return unless current_acct.twitter_enabled?
    asker_ids = User.askers.collect(&:id)
    last_post = Post.where("provider like 'twitter' and provider_post_id is not null and id not in (?)", asker_ids).last
    client = current_acct.twitter
    mentions = client.mentions({:count => 50, :since_id => last_post.nil? ? nil : last_post.provider_post_id.to_i})
    retweets = client.retweets_of_me({:count => 50, :since_id => last_post.nil? ? nil : last_post.provider_post_id.to_i})
    mentions.each do |m|
      Post.save_mention_data(m, current_acct)
    end

    retweets.each do |r|
      Post.save_retweet_data(r, current_acct)
    end
    true
  end

  def self.save_mention_data(m, current_acct)
    u = User.find_or_create_by_twi_user_id(m.user.id)
    u.update_attributes(:twi_name => m.user.name,
                        :twi_screen_name => m.user.screen_name,
                        :twi_profile_img_url => m.user.status.nil? ? nil : m.user.status.user.profile_image_url)
    post = Post.find_by_provider_post_id(m.id.to_s)
    return if post
    reply_post = Post.find_by_provider_post_id(m.in_reply_to_status_id.to_s) if m.in_reply_to_status_id
    if reply_post and reply_post.is_parent?
      conversation = Conversation.create(:publication_id => reply_post.publication_id,
                                         :post_id => reply_post.id,
                                         :user_id => u.id)
    elsif reply_post and reply_post.conversation_id
      conversation = reply_post.conversation
    else
      puts "Something went wrong on line 277 of post.rb"
    end      
    Post.create( :provider_post_id => m.id.to_s,
                 :engagement_type => nil,
                 :text => m.text,
                 :provider => 'twitter',
                 :user_id => u.id,
                 :in_reply_to_post_id => reply_post ? reply_post.id : nil,
                 :in_reply_to_user_id => current_acct.id,
                 :created_at => m.created_at,
                 :conversation_id => conversation.nil? ? nil : conversation.id,
                 :posted_via_app => false
                 )
  end

  def self.save_retweet_data(r, current_acct)
    retweet_post = Post.find_by_provider_post_id(r.id.to_s)
    users = current_acct.twitter.retweeters_of(r.id)
    users.each do |user|
      u = User.find_or_create_by_twi_user_id(user.id)
      u.update_attributes(:twi_name => m.user.name,
                          :twi_screen_name => m.user.screen_name,
                          :twi_profile_img_url => m.user.status.nil? ? nil : m.user.status.user.profile_image_url)
      post = Post.where("user_id = ? and in_reply_to_post_id = ? and engagement_type like '%share%'",u.id, retweet_post.id).first
      return if post
      Post.create(:engagement_type => 'share',
                 :provider => 'twitter',
                 :user_id => u.id,
                 :in_reply_to_post_id => retweet_post.id,
                 :in_reply_to_user_id => retweet_post.user_id,
                 :posted_via_app => false
                 )
    end
  end


  def generate_response(response_type)
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

  def respond(correct, publication_id, question_id, asker_id)
    #@TODO update engagement_type
    #@TODO create migration for new REP model
    self.update_attributes(:responded_to => true)
      unless correct.nil?
        Rep.create(:user_id => self.user_id,
                 :post_id => self.in_reply_to_post_id,
                 :publication_id => publication_id,
                 :question_id => question_id,
                 :correct => correct)

        stat = Stat.find_or_create_by_date_and_asker_id(Date.today.to_s, asker_id)
        stat.increment(:twitter_answers) if self.provider.include? 'twitter'
        stat.increment(:facebook_answers) if self.provider.include? 'facebook'
        stat.increment(:tumblr_answers) if self.provider.include? 'tumblr'
        stat.increment(:internal_answers) if self.provider.include? 'app'
      end
  end
end
