class FeedsController < ApplicationController
  before_filter :admin?, :only => [:manage]

  def index
    @asker = User.find(1)
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]

    @publications, posts, replies = Publication.recently_published
    post_pub_map = {}
    posts.each { |post| post_pub_map[post.id] = post.publication_id }

    @actions = {}
    replies.each do |post_id, post_activity|
      @actions[post_pub_map[post_id]] = []
      post_activity.each do |action|
        @actions[post_pub_map[post_id]] << {
          :user => {
            :id => action.user.id,
            :twi_screen_name => action.user.twi_screen_name,
            :twi_profile_img_url => action.user.twi_profile_img_url
          },
          :interaction_type => action.interaction_type, 
        } unless @actions[post_pub_map[post_id]].nil?
      end
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
      @actions = {}
      post_pub_map = {}
      posts.each { |post| post_pub_map[post.id] = post.publication_id }
      actions.each do |post_id, post_activity|
        @actions[post_pub_map[post_id]] = []
        post_activity.each do |action|
          @actions[post_pub_map[post_id]] << {
            :user => {
              :id => action.user.id,
              :twi_screen_name => action.user.twi_screen_name,
              :twi_profile_img_url => action.user.twi_profile_img_url
            },
            :interaction_type => action.interaction_type, 
          } unless @actions[post_pub_map[post_id]].nil?
        end
      end

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
      @followers = Stat.where(:asker_id => @asker.id).order('date DESC').limit(1).first.try(:total_followers) || 0
      
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
        Rails.cache.write("follower_ids:#{current_user.id}", user_followers = current_user.twitter.follower_ids().ids, :timeToLive => 2.days)
      end
    end
    @stream = []
    time_ago = 8.hours
    if user_followers.present?
      recent_posts = Post.joins(:user)\
        .where("users.twi_user_id in (?) and users.id not in (?) and (posts.interaction_type = 3 or (posts.interaction_type = 2 and posts.correct is not null)) and posts.created_at > ? and conversation_id is not null", user_followers, asker_ids, time_ago.ago)\
        .order("created_at DESC")\
        .limit(5)\
        .includes(:conversation => {:publication => :question})\
        .to_a
      recent_posts.group_by(&:user_id).each do |user_id, posts| 
        post = posts.shift
        @stream << post
        recent_posts.delete post
      end
      @stream << recent_posts.shift while (@stream.size < 5 and recent_posts.present?)
    end
    if @stream.size < 5
      users = User.includes(:posts)\
        .where("users.last_answer_at is not null and users.id not in (?)", (asker_ids + user_followers))\
        .order("users.last_answer_at DESC")\
        .limit(5 - @stream.size)\
        
      users.each do |user| 
        post = user.posts.where("posts.interaction_type = 2 and posts.correct is not null").order("created_at DESC").limit(1).first
        @stream << post unless post.blank?
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
    @conversation = Post.app_response(current_user, params["asker_id"], params["post_id"], params["answer_id"])
    @local_asker = User.askers.find(params["asker_id"])
    render :partial => "conversation"
  end

  def manager_response(in_reply_to = nil)
    asker = User.asker(params[:asker_id])
    user_post = Post.find(params[:in_reply_to_post_id])
    correct = (params[:correct].nil? ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil)
    conversation = user_post.conversation || Conversation.create(:post_id => user_post.id, :user_id => asker.id ,:publication_id => params[:publication_id])
    if params[:interaction_type] == "4"
      user = user_post.user
      dm = params[:message].gsub("@#{params[:username]}", "")
      if correct.present?
        user_post.update_attribute(:correct, correct)
        # Mixpanel tracking for DM answer conversion
        Mixpanel.track_event "answered", {
          :distinct_id => params[:in_reply_to_user_id],
          :time => user_post.created_at.to_i,
          :account => asker.twi_screen_name,
          :type => "twitter",
          :in_reply_to => "new follower question DM"
        }
      end
      response_post = Post.dm(asker, user, params[:message].gsub("@#{params[:username]}", ""), {:conversation_id => conversation.id})
      user.update_user_interactions({
        :learner_level => (correct.present? ? "dm answer" : "dm"), 
        :last_interaction_at => user_post.created_at,
        :last_answer_at => (correct.present? ? user_post.created_at : nil)
      })
    else
      
      response_text = params[:message].gsub("@#{params[:username]}", "")

      if params[:publication_id] and params[:correct]
        pub = Publication.find(params[:publication_id].to_i)
        # pub.question.resource_url ? resource_url = "#{URL}/posts/#{post.id}/refer" : resource_url = "#{URL}/questions/#{publication.question_id}/#{publication.question.slug}"

        post = pub.posts.where(:provider => "twitter").first
        user_post.update_responded(correct, params[:publication_id].to_i, pub.question_id, params[:asker_id])
        user_post.update_attribute(:correct, correct)
        long_url = (params[:publication_id].nil? ? nil : "#{URL}/feeds/#{params[:asker_id]}/#{params[:publication_id]}")
        if correct.nil? or correct
          resource_url = nil
          wisr_question = false
        else
          if pub.question.resource_url.nil?
            resource_url = "#{URL}/questions/#{pub.question_id}/#{pub.question.slug}"
            wisr_question = true
          else
            resource_url = "#{URL}/posts/#{post.id}/refer"
            wisr_question = false
          end
        end         

        if params[:correct] == "false" and Post.create_split_test(params[:in_reply_to_user_id], "include answer in response", "false", "true") == "true"
          correct_answer = pub.question.answers.where(:correct => true).first()
          response_text = "#{['Sorry', 'Nope', 'No'].sample}, I was looking for '#{correct_answer.text}'"
          resource_url = nil
          wisr_question = nil
        end

        response_post = Post.tweet(asker, response_text, {
          :reply_to => params[:username], 
          :long_url => long_url, 
          :interaction_type => 2, 
          :conversation_id => conversation.id,
          :in_reply_to_post_id => params[:in_reply_to_post_id], 
          :in_reply_to_user_id => params[:in_reply_to_user_id], 
          :link_to_parent => false,
          :resource_url => resource_url,
          :wisr_question => wisr_question,
          :intention => 'grade'
        })
        user = user_post.user
        user.update_user_interactions({
          :learner_level => (correct.present? ? "twitter answer" : "mention"), 
          :last_interaction_at => user_post.created_at,
          :last_answer_at => (correct.present? ? user_post.created_at : nil)
        })

        # Check if we should ask for UGC
        User.request_ugc(user, asker)

        # Check if in response to re-engage message
        if Post.where("in_reply_to_user_id = ? and (intention = ? or intention = ?)", params[:in_reply_to_user_id], 'reengage inactive', 'reengage last week inactive').present?
          Post.trigger_split_test(params[:in_reply_to_user_id], 'reengage last week inactive') 
          in_reply_to = "reengage inactive"
        # Check if in response to incorrect answer follow-up
        elsif Post.joins(:conversation).where("posts.intention = ? and posts.in_reply_to_user_id = ? and conversations.publication_id = ? and posts.created_at > ?", 'incorrect answer follow up', params[:in_reply_to_user_id], params[:publication_id].to_i, 1.week.ago).present?
          Post.trigger_split_test(params[:in_reply_to_user_id], 'include answer in response')
          in_reply_to = "incorrect answer follow up" 
        # Check if in response to first question mention
        elsif Post.joins(:conversation).where("posts.intention = ? and posts.in_reply_to_user_id = ? and conversations.publication_id = ? and posts.created_at > ?", 'new user question mention', params[:in_reply_to_user_id], params[:publication_id].to_i, 1.week.ago).present?
          in_reply_to = "new follower question mention"
        end

        Post.trigger_split_test(params[:in_reply_to_user_id], 'cohort re-engagement')

        # Fire mixpanel answer event
        Mixpanel.track_event "answered", {
          :distinct_id => params[:in_reply_to_user_id],
          :time => user_post.created_at.to_i,
          :account => asker.twi_screen_name,
          :type => "twitter",
          :in_reply_to => in_reply_to
        }
        
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

  def link_to_post
    if params[:link_to_pub_id] == "0"
      render :json => Post.find(params[:post_id]).update_attribute(:in_reply_to_post_id, nil)
    else
      post_to_link = Post.find(params[:post_id])
      post_to_link_to = Publication.find(params[:link_to_pub_id]).posts.where("in_reply_to_user_id is null").last
      post_to_link.update_attribute(:in_reply_to_post_id, post_to_link_to.id)
      render :json => [post_to_link, post_to_link_to]
    end
  end

  def manage
    #base selection
    @asker = Asker.find params[:id]
    @posts = Post.includes(:user).not_spam\
      .where("posts.in_reply_to_user_id = ? AND posts.user_id not in (?)", params[:id], Asker.all.collect(&:id))

    #filter for retweet, spam, starred
    if params[:filter] == 'retweets'
      @posts = @posts.requires_action.retweet.not_ugc
    elsif params[:filter] == 'spam'
      @posts = @posts.requires_action.spam.not_ugc
    elsif params[:filter] == 'ugc'
      @posts = @posts.ugc
    elsif params[:filter] == 'linked'
      @posts = @posts.requires_action.not_autocorrected.linked.not_ugc.not_spam.not_retweet
    elsif params[:filter] == 'unlinked'
      @posts = @posts.requires_action.not_autocorrected.unlinked.not_ugc.not_spam.not_retweet
    elsif params[:filter] == 'all'
      @posts = @posts.requires_action.not_spam.not_retweet
    else #params[:filter].nil? == 'autocorrected'
      @posts = @posts.requires_action.not_ugc.not_spam.not_retweet.autocorrected
    end

    @posts = @posts.order("posts.created_at DESC")
    @questions = @asker.publications.where(:published => true)\
      .order("created_at DESC").includes(:question => :answers).limit(100)
    @engagements, @conversations = Post.grouped_as_conversations @posts, @asker
  end

  def ask
    post = Post.tweet(current_user, params["text"], {
      :interaction_type => 2, 
      :in_reply_to_user_id => params["asker_id"], 
      :link_to_parent => false,
      :requires_action => true,
      :intention => "ask a question"
    })
    Post.trigger_split_test(current_user.id, 'ask a question')
    render :text => post.provider_post_id
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
