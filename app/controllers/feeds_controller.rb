class FeedsController < ApplicationController
  before_filter :authenticate_user, :except => [:index, :show, :activity_stream, :more]
  before_filter :admin?, :only => [:manage, :manager_response, :link_to_post, :manager_post]

  def index
    @asker = User.find(1)
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]

    @publications, posts, replies = Publication.recently_published
    post_pub_map = {}
    posts.each { |post| post_pub_map[post.id] = post.publication_id }
    
    @actions = {}
    replies.each do |post_id, post_activity|
      @actions[post_pub_map[post_id]] ||= []
      user_ids = []
      post_activity.each do |action|
        next if user_ids.include? action.user_id
        user = action.user
        user_ids << user.id        
        @actions[post_pub_map[post_id]] << {
          :user => {
            :id => user.id,
            :twi_screen_name => user.twi_screen_name,
            :twi_profile_img_url => user.twi_profile_img_url
          },
          :interaction_type => action.interaction_type, 
        } unless @actions[post_pub_map[post_id]].nil?
      end
      @actions[post_pub_map[post_id]].uniq!{|a| a[:user][:id]}
    end
    @pub_grouped_posts = posts.group_by(&:publication_id)

    if current_user      
      @responses = Conversation.where(:user_id => current_user.id, :post_id => posts.collect(&:id)).includes(:posts).group_by(&:publication_id) 
    else
      @responses = []
    end
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]

    @directory = {}
    User.askers.select([:id, :twi_screen_name, :twi_profile_img_url]).find(ACCOUNT_DATA.keys).group_by(&:id).each do |id, data| 
      @directory[ACCOUNT_DATA[id][:category]] = [] unless @directory[ACCOUNT_DATA[id][:category]] 
      @directory[ACCOUNT_DATA[id][:category]] << data[0]
    end
  end

  def show
    if @asker = Asker.find(params[:id])

      # publications, posts and user responses
      @publications, posts, actions = Publication.recently_published_by_asker(@asker)

      # user specific responses
      @responses = (current_user ? Conversation.where(:user_id => current_user.id, :post_id => posts.collect(&:id)).includes(:posts).group_by(&:publication_id) : [])

      # question activity
      @actions = Post.recent_activity_on_posts(posts, actions)

      # inject requested publication from params, render twi card
      if params[:post_id]
        @requested_publication = @asker.publications.find(params[:post_id])
        @publications.reverse!.push(@requested_publication).reverse! unless @publications.include? @requested_publication
        @render_twitter_card = true
      else
        @render_twitter_card = false     
      end

      # stats
      @question_count = @asker.publications.select(:id).where(:published => true).size
      @questions_answered = Post.where("in_reply_to_user_id = ? and correct is not null", params[:id]).count
      @followers = @asker.followers.size
      
      # misc
      @post_id = params[:post_id]
      @answer_id = params[:answer_id]
      @author = User.find @asker.author_id if @asker.author_id

      # related
      @related = Asker.select([:id, :twi_name, :description, :twi_profile_img_url])\
        .where(:id => ACCOUNT_DATA.keys.sample(3))

      @question_form = ((params[:question_form] == "1" or params[:q] == "1") ? true : false)

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @posts }
      end
    else
      redirect_to "/"
    end
  end

  def activity_stream(user_followers = [])
    asker_ids = User.askers.collect(&:id)
    if current_user
      unless (user_followers = (Rails.cache.read("follower_ids:#{current_user.id}") || [])).present?
        user_followers = Post.twitter_request { current_user.twitter.follower_ids().ids }
        Rails.cache.write("follower_ids:#{current_user.id}", user_followers, :timeToLive => 2.days)
      end
    end

    @stream = []
    time_ago = 8.hours
    if user_followers.present?
      recent_posts = Post.not_spam.joins(:user)\
        .where("users.twi_user_id in (?) and users.id not in (?) and (posts.interaction_type = 3 or (posts.interaction_type = 2)) and posts.created_at > ? and conversation_id is not null", user_followers, asker_ids, time_ago.ago)\
        .order("created_at DESC")\
        .limit(5)\
        .includes(:conversation => {:publication => :question})
      recent_posts.group_by(&:user_id).each do |user_id, posts|
        next if posts.empty?
        post = posts.first
        next unless post.conversation and post.conversation.publication
        @stream << posts.shift
      end
    end
    if @stream.size < 5
      users = User.where("users.last_answer_at is not null and users.id not in (?)", (asker_ids))\
        .order("users.last_answer_at DESC").limit(10)\
        .reject{|u| user_followers.include? u.id}
        
      users.each do |user| 
        post = user.posts.not_spam.includes(:conversation => :publication).where("posts.interaction_type = 2").order("created_at DESC").limit(1).first
        next unless post and post.conversation and post.conversation.publication
        @stream << post unless post.blank?
        break if @stream.size >= 5
      end
    end
    render :partial => "stream"
  end

  def more
    publication = Publication.includes(:posts).find(params[:last_post_id])
    if params[:id].to_i > 0
      @asker = User.asker(params[:id])
      @publications = @asker.publications.includes(:posts).where("publications.created_at < ? and publications.id != ? and publications.published = ? and posts.interaction_type = 1", publication.created_at, publication.id, true).order("posts.created_at DESC").limit(5).includes(:question => :answers)
    else
      post = publication.posts.where("interaction_type = 1").order("posts.created_at DESC").limit(1).first
      @publications = Publication.includes(:posts).where("posts.created_at < ? and publications.id != ? and publications.published = ? and posts.interaction_type = 1", post.created_at, publication.id, true).order("posts.created_at DESC").limit(5).includes(:question => :answers)
    end

    if current_user     
      @responses = Conversation.where(:user_id => current_user.id, :post_id => Post.select(:id).where(:provider => "twitter", :publication_id => @publications.collect(&:id)).collect(&:id)).includes(:posts).group_by(&:publication_id) 
    else
      @responses = []
    end    
    posts = Post.select([:id, :created_at, :publication_id]).where(:provider => "twitter", :publication_id => @publications.collect(&:id)).order("created_at DESC")
    
    @actions = post_pub_map = {}
    posts.each { |post| post_pub_map[post.id] = post.publication_id }
    
    Post.select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at]).where(:in_reply_to_post_id => posts.collect(&:id)).order("created_at ASC").includes(:user).group_by(&:in_reply_to_post_id).each do |post_id, post_activity|
      @actions[post_pub_map[post_id]] = []
      post_activity.each do |action|
        @actions[post_pub_map[post_id]] << {
          :user => {
            :id => action.user.id,
            :twi_screen_name => action.user.twi_screen_name,
            :twi_profile_img_url => action.user.twi_profile_img_url
          },
          :interaction_type => action.interaction_type, 
        }
      end
    end
    @pub_grouped_posts = posts.group_by(&:publication_id)     
    if @publications.blank?
      render :json => false
    else
      render :partial => "feed"
    end
  end

  def scores
    @scores = User.get_top_scorers(params[:id])
  end

  def respond_to_question
    publication = Publication.find(params[:publication_id])
    @question_asker = Asker.find(params[:asker_id])
    answer = Answer.find(params[:answer_id])
    
    # Set parent post for wisr response - is this necessary?
    post = publication.posts.statuses.order("created_at DESC").limit(1).first

    # Create conversation for posts
    @conversation = Conversation.create({
      :user_id => current_user.id,
      :post_id => post.id,
      :publication_id => publication.id
    })

    post_aggregate_activity = Post.create_split_test(current_user.id, "post aggregate activity", "false", "true") == "true" ? true : false

    user_post = current_user.app_answer(@question_asker, post, answer, { :post_aggregate_activity => post_aggregate_activity })
    @conversation.posts << user_post
    asker_response = @question_asker.app_response(user_post, answer.correct, { :post_aggregate_activity => post_aggregate_activity }) if user_post
    @conversation.posts << asker_response

    render :partial => "conversation"
  end

  def manager_response
    asker = Asker.find(params[:asker_id])
    user_post = Post.find(params[:in_reply_to_post_id])
    correct = (params[:correct].nil? ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil)

    unless conversation = user_post.conversation
      conversation = Conversation.create(:post_id => user_post.id, :user_id => asker.id, :publication_id => params[:publication_id])
      conversation.posts << user_post
    end

    if params[:interaction_type] == "4"
      user = user_post.user
      response_text = params[:message].gsub("@#{params[:username]}", "")

      if correct.present?
        response_text = asker.get_DM_answer_nudge_script(response_text, user.id)

        user_post.update_attribute(:correct, correct)

        # Double counting if we grade people again via DM
        Mixpanel.track_event "answered", {
          :distinct_id => params[:in_reply_to_user_id],
          :time => user_post.created_at.to_i,
          :account => asker.twi_screen_name,
          :type => "twitter",
          :in_reply_to => "new follower question DM"
        }
      end
      
      response_post = Post.dm(asker, user, response_text, {
        :conversation_id => conversation.id
      })

      user.update_user_interactions({
        :learner_level => (correct.present? ? "dm answer" : "dm"), 
        :last_interaction_at => user_post.created_at,
        :last_answer_at => (correct.present? ? user_post.created_at : nil)
      })
    else
      response_text = params[:message].gsub("@#{params[:username]}", "")
      if params[:correct]
        response_post = asker.app_response(user_post, correct, { 
          :post_aggregate_activity => false, 
          :response_text => response_text
        })
        conversation.posts << response_post
      else         
        response_post = Post.tweet(asker, response_text, {
          :reply_to => params[:username], 
          :interaction_type => 2, 
          :conversation_id => conversation.id,
          :in_reply_to_post_id => params[:in_reply_to_post_id], 
          :in_reply_to_user_id => params[:in_reply_to_user_id], 
          :link_to_parent => true
        })    
      end
    end

    user_post.update_attributes({:requires_action => false, :conversation_id => conversation.id}) if response_post
    render :json => response_post.present?
  end

  # This should really be rolled up into mgr response!!!
  def manager_post user_id = nil, interaction_type = 1
    asker = Asker.find(params[:asker_id])
    response_text = params[:text]

    if params[:text].include? "@"
      user_id = User.find_by_twi_screen_name(params[:text].match(/@[A-Za-z0-9-_]*/).to_s.gsub("@", "")).id
      interaction_type = 2
    end

    response_post = Post.tweet(asker, response_text, {
      :reply_to => user_name, 
      :interaction_type => interaction_type, 
      :in_reply_to_user_id => user_id
    }) 

    render :json => response_post
  end

  def link_to_post
    if params[:link_to_pub_id] == "0"
      render :json => Post.find(params[:post_id]).update_attribute(:in_reply_to_post_id, nil)
    else
      post_to_link = Post.find(params[:post_id])
      publication = Publication.find(params[:link_to_pub_id])
      root_post = publication.posts.last

      post_to_link_to = publication.posts.where("in_reply_to_user_id is null").last
      post_to_link.update_attribute(:in_reply_to_post_id, post_to_link_to.id)
      conversation = Conversation.create(:post_id => root_post.id, :user_id => post_to_link.user_id ,:publication_id => publication.id)
      
      Post.grader.grade post_to_link

      render :json => [post_to_link, post_to_link_to]
    end
  end

  def manage
    #base selection
    @asker = Asker.find params[:id]
    @posts = Post.includes(:user, :conversation => :posts).not_spam.not_us.where("posts.in_reply_to_user_id = ?", params[:id])

    @linked_box_count = @posts.linked_box.count
    @unlinked_box_count = @posts.unlinked_box.count
    @autocorrected_box_count = @posts.autocorrected_box.count

    #filter for retweet, spam, starred
    if params[:filter] == 'retweets'
      @posts = @posts.retweet_box
    elsif params[:filter] == 'spam'
      @posts = @posts.spam_box
    elsif params[:filter] == 'ugc'
      @posts = @posts.ugc_box
    elsif params[:filter] == 'linked'
      @posts = @posts.linked_box
    elsif params[:filter] == 'unlinked'
      @posts = @posts.unlinked_box
    elsif params[:filter] == 'all'
      @posts = @posts.all_box
    else
      @posts = @posts.autocorrected_box
    end

    @posts = @posts.order("posts.created_at DESC")
    @questions = @asker.publications.where(:published => true)\
      .order("created_at DESC").includes(:question => :answers).limit(100)
    @engagements, @conversations = Post.grouped_as_conversations @posts, @asker
  end

  def create_split_test
    res = Post.create_split_test(params[:user_id], params[:test_name], params[:alt_a], params[:alt_b])
    render :text => res.nil? ? 'error' : res, :status => 200
  end

  def trigger_split_test
    res = Post.trigger_split_test(params[:user_id], params[:test_name], params[:reset])
    human_res = res.nil? ? 'Error- could not complete action' : res ? "New Finish" : "Already Completed"
    render :text => human_res, :status => 200
  end
end
