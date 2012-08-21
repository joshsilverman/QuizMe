class Post < ActiveRecord::Base
	belongs_to :question
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
  belongs_to :publication
	belongs_to :parent, :class_name => 'Post', :foreign_key => 'parent_id'
  has_many :engagements
  has_many :conversations
	has_many :reps
  has_many :posts, :class_name => 'Post', :foreign_key => 'parent_id'

  URL = "http://studyegg-quizme-staging.herokuapp.com"

	def self.shorten_url(url, source, lt, campaign, question_id=nil)
		authorize = UrlShortener::Authorize.new 'o_29ddlvmooi', 'R_4ec3c67bda1c95912185bc701667d197'
    shortener = UrlShortener::Client.new authorize
    short_url = shortener.shorten("#{url}?s=#{source}&lt=#{lt}&c=#{campaign}").urls
    short_url
	end

  def self.publish(provider, asker, publication)
    question = Question.find(publication.question_id)
    post = Post.create(
      :user_id => asker.id,
      :provider => provider,
      :text => question.text,
      :engagement_type => 'question', 
      :publication_id => publication.id, 
      :posted_via_app => true
    )
    ## Update to production
    short_url = Post.shorten_url("#{URL}/feeds/#{asker.id}/#{post.id}", "app", "ans", asker.twi_screen_name, question.id)
    case provider
    when "twitter"
      response = asker.twitter.update(Post.tweetable(post.text, "", short_url))   
      post.update_attribute(:provider_post_id, response.id)
    when "tumblr"
      # CHECK WITH BILL
      # puts "tum"
      # response = asker.tumblr.text(
      #   asker.tum_url,
      #   :title => "Daily Quiz!",
      #   :body => "#{text} #{short_url}"
      # )
    else  
      puts "Boo"
    end
    publication.posts << post
    # puts "publication posts:"
    # puts publication.posts.to_json
    return post
  end

  def self.tweet(account, tweet, engagement_type, 
                 long_url, link_type, conversation_id,
                 publication_id, in_reply_to_post_id, 
                 in_reply_to_user_id)
    return unless account.twitter_enabled?

    short_url = Post.shorten_url(long_url, 'twi', link_type, account.twi_screen_name) if long_url
    parent_post = Post.find(in_reply_to_post_id)
    response = account.twitter.update("#{tweet} #{short_url}", {'in_reply_to_status_id' => parent_post.provider_post_id.to_i})
    Post.create(
      :user_id => account.id,
      :provider => 'twitter',
      :text => tweet,
      :link_type => link_type,
      :engagement_type => engagement_type,
      :provider_post_id => response.id.to_s,
      :in_reply_to_post_id => in_reply_to_post_id,
      :in_reply_to_user_id => in_reply_to_user_id,
      :conversation_id => conversation_id,
      :publication_id => publication_id,
      :posted_via_app => provider_post_id
    )
  end

  def self.app_response(current_user, asker_id, publication_id, answer_id)
    # Post the user's answer to Twitter
    # Generate a response
    # Post the response to Twitter
    # Return the response text
    asker = User.asker(asker_id)
    publication = Publication.find(publication_id)
    answer = Answer.select([:text, :correct]).find(answer_id)
    status = (answer.correct ? "correct" : "incorrect")
    post = publication.posts.where(:provider => "twitter").first
    conversation = Conversation.find_or_create_by_user_id_and_post_id_and_publication_id(current_user.id, post.id, publication_id)

    # conversation.posts << Post.tweet(current_user, answer.text, "reply answer #{status}", "#{URL}/feeds/#{asker.id}/#{publication_id}", link_type, conversation_id,
    #              publication_id, in_reply_to_post_id, 
    #              in_reply_to_user_id)
    # response = Post.generate_response()
    # conversation.posts << Post.tweet(asker, response, "reply answer_response #{status}", "#{URL}/feeds/#{asker.id}/#{publication_id}", link_type, conversation_id,
    #              publication_id, in_reply_to_post_id, 
    #              in_reply_to_user_id)
    # return response


    # puts "app response"
    # asker = User.asker(asker_id)
    # publication = Publication.find(publication_id)
    # post = Post.find(post_id)
    # answer = Answer.select([:text, :correct]).find(answer_id)
    # short_url = Post.shorten_url("http://studyegg-quizme-staging.herokuapp.com/feeds/#{asker.id}/#{publication.id}", "twitter", (answer.correct ? "cor" : "inc"), asker.twi_screen_name, publication.question_id)
    # Post.tweet()
    # Post.tweetable("test", "this", "http://studyegg-quizme-staging.herokuapp.com/feeds")

    # puts short_url
    # puts current_user.to_json
    # puts asker.to_json
    # puts publication.to_json
    # puts answer.to_json
    # conversation = Conversation.find_or_create_by_user_id_and_post_id(current_user.id, post.id)
    # conversation.update_attribute(:publication_id, post.publication_id)
    # puts conversation.to_json

    
    # tweet = "@#{asker.twi_name} #{answer.tweetable(asker.twi_name, post.url)} #{post.url}"
    # eng = Post.tweet(current_user, tweet, {
    #   :asker_id => asker_id, 
    #   :post_id => post_id, 
    #   :in_reply_to_status_id => post.sibling('twitter').provider_post_id
    # })
    # tweet_response = eng.generate_response(answer.correct ? 'correct' : 'incorrect')
    # Post.tweet(asker, tweet_response, {
    #   :url => "http://studyegg-quizme-staging.herokuapp.com/feeds/#{asker_id}/#{post.id}",
    #   :link_type => answer.correct ? 'cor' : 'inc', 
    #   :question_id => nil, 
    #   :parent_id => nil, 
    #   :in_reply_to_status_id => eng.provider_post_id
    # })
    # eng.respond(answer.correct)
    # return tweet_response   
  end

  def self.tumbl()

  end


  def self.tweetable(text, user = "", url = "", tweet = "", remaining = 140)
    text_length = text.length
    handle_length = user.length
    url_length = url.length
    remaining = (remaining - (handle_length + 2)) if handle_length > 0
    remaining = (remaining - (url_length + 1)) if url_length > 0
    truncated_text = text[0..(remaining - 4)]
    truncated_text += "..." if text_length > remaining
    tweet += "@#{user} " if handle_length > 0
    tweet += "#{truncated_text}"
    tweet += " #{url}" if url_length > 0
    return tweet    
  end

  # def tweetable(user = "", url = "", tweet = "")
  #   length = self.text.length
  #   overage = (140 - user.length - 2 - length - 1 - url.length)
  #   overage < 0 ? truncation = length - overage.abs : truncation = length
  #   truncated_text = Post.truncate(text, truncation)
  #   tweet += "@#{user}" if user.present?
  #   tweet += " #{truncated_text}"
  #   tweet += " #{url}" if url.present?
  #   return tweet
  # end

  # def self.tweet(account, tweet, params)
  #   if account[:role] == "asker"
  #     return Post.asker_tweet(account, tweet, params[:url], params[:link_type], params[:question_id], params[:parent_id], params[:in_reply_to_status_id], params[:short_url])
  #   else
  #     return Post.user_tweet(account, tweet, params[:asker_id], params[:post_id], params[:in_reply_to_status_id])
  #   end
  # end

  def self.user_tweet(current_user, tweet, asker_id, post_id, in_reply_to_status_id)
    res = current_user.twitter.update("#{tweet}", {'in_reply_to_status_id' => in_reply_to_status_id})
    eng = Engagement.create(
      :text => res.text, 
      :date => "#{res.created_at.year}-#{res.created_at.month}-#{res.created_at.day}",
      :engagement_type => "answer mention",
      :provider => "app",
      :provider_post_id => res.id,
      :twi_in_reply_to_status_id => in_reply_to_status_id,
      :user_id => current_user.id,
      :post_id => post_id,
      :created_at => res.created_at,
      :asker_id => asker_id
    ) 
    return eng
  end

  def self.asker_tweet(current_acct, tweet, url, lt, question_id, parent_id, in_reply_to_status_id = nil, short_url = nil)
    ## TODO new param for source (app for responses through wisr, twi for to twitter)
    short_url = Post.shorten_url(url, 'app', lt, current_acct.twi_screen_name, question_id) if url
    response = current_acct.twitter.update("#{tweet} #{short_url}", {'in_reply_to_status_id' => in_reply_to_status_id})
    Post.create(
      :asker_id => current_acct.id,
      :question_id => question_id,
      :provider => 'twitter',
      :text => tweet,
      :url => short_url,
      :link_type => lt,
      :post_type => 'status',
      :provider_post_id => response.id.to_s,
      :parent_id => parent_id
    )
    return response 
  end

  def self.respond_wisr(current_user, asker_id, post_id, answer_id)
    asker = User.asker(asker_id)
    post = Post.find(post_id)
    answer = Answer.select([:text, :correct]).find(answer_id)
    tweet = "@#{asker.twi_name} #{answer.tweetable(asker.twi_name, post.url)} #{post.url}"
    eng = Post.tweet(current_user, tweet, {
      :asker_id => asker_id, 
      :post_id => post_id, 
      :in_reply_to_status_id => post.sibling('twitter').provider_post_id
    })
    tweet_response = eng.generate_response(answer.correct ? 'correct' : 'incorrect')
    Post.tweet(asker, tweet_response, {
      :url => "http://studyegg-quizme-staging.herokuapp.com/feeds/#{asker_id}/#{post.id}",
      :link_type => answer.correct ? 'cor' : 'inc', 
      :question_id => nil, 
      :parent_id => nil, 
      :in_reply_to_status_id => eng.provider_post_id
    })
    eng.respond(answer.correct)
    return tweet_response
  end

  def self.dm(current_acct, tweet, url, lt, question_id, user_id)
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
  
  def self.app_post(current_acct, question, question_id, parent_id)
    post = Post.create(
      :asker_id => current_acct.id,
      :question_id => question_id,
      :provider => 'app',
      :text => question,
      :post_type => 'question',
      :parent_id => parent_id
    )
    short_url = Post.shorten_url("http://studyegg-quizme-staging.herokuapp.com/feeds/#{current_acct.id}/#{post.id}", 'app', "ans", current_acct.twi_screen_name, question_id)
    post.update_attribute(:url, short_url)
    return post
  end

  def self.create_tumblr_post(current_acct, text, url, lt, question_id, parent_id)
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

  def sibling(provider)
    self.parent.posts.where(:provider => provider).first
  end

  def child(provider)
    self.posts.where(:provider => provider).first
  end
end
