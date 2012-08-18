class Post < ActiveRecord::Base
	belongs_to :question
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	has_many :engagements
	has_many :reps
  belongs_to :parent, :class_name => 'Post', :foreign_key => 'parent_id'
  has_many :posts, :class_name => 'Post', :foreign_key => 'parent_id'

	def self.shorten_url(url, source, lt, campaign, question_id)
		authorize = UrlShortener::Authorize.new 'o_29ddlvmooi', 'R_4ec3c67bda1c95912185bc701667d197'
    shortener = UrlShortener::Client.new authorize
    short_url = shortener.shorten("#{url}?s=#{source}&lt=#{lt}&c=#{campaign}").urls
    short_url
	end


	# def self.tweet(current_acct, tweet, url, lt, question_id, parent_id, in_reply_to_status_id = nil)
  def self.tweet(account, tweet, params)
    if account[:role] == "asker"
      return Post.asker_tweet(account, tweet, params[:url], params[:link_type], params[:question_id], params[:parent_id], params[:in_reply_to_status_id], params[:short_url])
    else
      return Post.user_tweet(account, tweet, params[:asker_id], params[:post_id], params[:in_reply_to_status_id])
    end
  end

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
    Post.create(:asker_id => current_acct.id,
                :question_id => question_id,
                :to_twi_user_id => user_id,
                :provider => 'twitter',
                :text => tweet,
                :url => url.nil? ? nil : short_url,
                :link_type => lt,
                :post_type => 'dm',
                :provider_post_id => res.id.to_s)
  end
  
  def self.app_post(current_acct, question, question_id, parent_id)
    post = Post.create(:asker_id => current_acct.id,
                :question_id => question_id,
                :provider => 'app',
                :text => question,
                :post_type => 'question',
                :parent_id => parent_id)
    short_url = Post.shorten_url("http://studyegg-quizme-staging.herokuapp.com/feeds/#{current_acct.id}/#{post.id}", 'app', "ans", current_acct.twi_screen_name, question_id)
    post.update_attribute(:url, short_url)
    post
  end

  def self.create_tumblr_post(current_acct, text, url, lt, question_id, parent_id)
    short_url = Post.shorten_url(url, 'tum', lt, current_acct.twi_screen_name, question_id)
    res = current_acct.tumblr.text(current_acct.tum_url,
                                    :title => "Daily Quiz!",
                                    :body => "#{text} #{short_url}")
    Post.create(:asker_id => current_acct.id,
                :question_id => question_id,
                :provider => 'tumblr',
                :text => text,
                :url => short_url,
                :link_type => lt,
                :post_type => 'text',
                :provider_post_id => res.id.to_s,
                :parent_id => parent_id)
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
