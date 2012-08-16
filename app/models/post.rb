class Post < ActiveRecord::Base
	belongs_to :question
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	has_many :engagements
	has_many :reps
  belongs_to :parent, :class_name => 'Post', :foreign_key => 'parent_id'
  has_many :posts, :class_name => 'Post', :foreign_key => 'parent_id'

	def self.shorten_url(url, source, lt, campaign, question_id, link_to_quizme=false)
		authorize = UrlShortener::Authorize.new 'o_29ddlvmooi', 'R_4ec3c67bda1c95912185bc701667d197'
    shortener = UrlShortener::Client.new authorize
    short_url = nil
    if link_to_quizme
      short_url = shortener.shorten("#{url}?s=#{source}&lt=#{lt}&c=#{campaign}#question_#{question_id}").urls
    else
      short_url = shortener.shorten("#{url}?s=#{source}&lt=#{lt}&c=#{campaign}").urls
    end
    short_url
	end

	def self.tweet(current_acct, tweet, url, lt, question_id, parent_id)
    short_url = nil
		short_url = Post.shorten_url(url, 'twi', lt, current_acct.twi_screen_name, question_id, current_acct.link_to_quizme) if url
    res = current_acct.twitter.update("#{tweet} #{short_url}")
    Post.create(:asker_id => current_acct.id,
                :question_id => question_id,
                :provider => 'twitter',
                :text => tweet,
                :url => short_url,
                :link_type => lt,
                :post_type => 'status',
                :provider_post_id => res.id.to_s,
                :parent_id => parent_id)
    res
  end

  def self.respond_wisr(asker_id, answer_id)
    answer = Answer.select([:text, :correct]).find(answer_id)
    handle = User.select(:twi_name).asker(asker_id).twi_name
    tweet = "@#{handle} #{answer.tweetable(handle)}"
    # res = Post.tweet(current_user, tweet, nil, nil, question_id, )
  #   eng = Engagement.create(:text => res.text ...) #@TODO fill out engagement creation
  #   tweet_response= eng.generate_response(correct)
  #   Post.tweet(@asker, tweet_response, url, lt, nil)
  #   tweet_response
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
  	Post.create(:asker_id => current_acct.id,
                :question_id => question_id,
                :provider => 'app',
                :text => question,
                :post_type => 'question',
                :parent_id => parent_id)
  end

  def self.create_tumblr_post(current_acct, text, url, lt, question_id, parent_id)
    short_url = Post.shorten_url(url, 'tum', lt, current_acct.twi_screen_name)
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
end
