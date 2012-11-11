class FeedsController < ApplicationController
  before_filter :admin?, :only => [:manage]

  def index
    @asker = User.find(1)
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]    
    @publications = Publication.where(:published => true).order("updated_at DESC").limit(15).includes(:question => :answers)
    posts = Post.select([:id, :created_at, :publication_id]).where(:provider => "twitter", :publication_id => @publications.collect(&:id)).order("created_at DESC")
    @actions = {}
    post_pub_map = {}
    posts.each { |post| post_pub_map[post.id] = post.publication_id }
    Post.select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at]).where(:in_reply_to_post_id => posts.collect(&:id)).order("created_at ASC").includes(:user).group_by(&:in_reply_to_post_id).each do |post_id, post_activity|
      @actions[post_pub_map[post_id]] = []
      post_activity.each do |action|
        @actions[post_pub_map[post_id]] << {
          :user => {
            :twi_screen_name => action.user.twi_screen_name,
            :twi_profile_img_url => action.user.twi_profile_img_url
          },
          :interaction_type => action.interaction_type, 
        } unless @actions[post_pub_map[post_id]].nil?
      end
    end
    # if params[:post_id]
    #   requested_publication = Publication.find(params[:post_id])
    #   @publications.reverse!.push(requested_publication).reverse! unless @publications.include? requested_publication
    # end
    @pub_grouped_posts = posts.group_by(&:publication_id)

    # posts = Post.select([:id, :created_at, :publication_id]).where(:provider => "twitter", :publication_id => @publications.collect(&:id))
    # @post_times = posts.group_by(&:publication_id)
    publication_ids = Publication.select(:id).where(:published => true)
    @question_count = publication_ids.size
    @questions_answered = Post.where("correct is not null", params[:id]).count
    @followers = Stat.where("created_at > ? and created_at < ?", Date.yesterday.beginning_of_day, Date.yesterday.end_of_day).sum(:total_followers) || 0
    # @leaders = User.leaderboard(params[:id])
    if current_user
      # @correct = 0
      # @leaders[:scores].each do |user|
      #   next if user[:user].id != current_user.id or @correct != 0
      #   @correct = user[:correct]
      # end        
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

    # if @asker.author_id
    #   @author = User.find @asker.author_id
    # end    
  end

  def show
    @asker = User.asker(params[:id])
    if @asker
      @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID != ? AND published = ?", @asker.id, true).sample(3)
      # @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID in (?)", ACCOUNT_DATA[@asker.id][:retweet]).sample(3)
      @publications = @asker.publications.where("published = ?", true).order("updated_at DESC").limit(15).includes(:question => :answers)

      posts = Post.select([:id, :created_at, :publication_id]).where(:provider => "twitter", :publication_id => @publications.collect(&:id)).order("created_at DESC")
      
      @actions = {}
      post_pub_map = {}
      posts.each { |post| post_pub_map[post.id] = post.publication_id }
      Post.select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at]).where(:in_reply_to_post_id => posts.collect(&:id)).order("created_at ASC").includes(:user).group_by(&:in_reply_to_post_id).each do |post_id, post_activity|
        @actions[post_pub_map[post_id]] = []
        post_activity.each do |action|
          @actions[post_pub_map[post_id]] << {
            :user => {
              :twi_screen_name => action.user.twi_screen_name,
              :twi_profile_img_url => action.user.twi_profile_img_url
            },
            :interaction_type => action.interaction_type, 
          } unless @actions[post_pub_map[post_id]].nil?
        end
      end

      @pub_grouped_posts = posts.group_by(&:publication_id)

      #inject requested publication from params
      if params[:post_id]
        requested_publication = @asker.publications.find(params[:post_id])
        @publications.reverse!.push(requested_publication).reverse! unless @publications.include? requested_publication
      end
      # posts = Post.select([:id, :created_at, :publication_id]).where(:provider => "twitter", :publication_id => @publications.collect(&:id))
      # @post_times = posts.group_by(&:publication_id)
      publication_ids = @asker.publications.select(:id).where(:published => true)
      @question_count = publication_ids.size
      @questions_answered = Post.where("in_reply_to_user_id = ? and correct is not null", params[:id]).count
      @followers = Stat.where(:asker_id => @asker.id).order('date DESC').limit(1).first.try(:total_followers) || 0
      @leaders = User.leaderboard(params[:id])
      if current_user
        @correct = 0
        @leaders[:scores].each do |user|
          next if user[:user].id != current_user.id or @correct != 0
          @correct = user[:correct]
        end        
        @responses = Conversation.where(:user_id => current_user.id, :post_id => posts.collect(&:id)).includes(:posts).group_by(&:publication_id) 
      else
        @responses = []
      end
      @post_id = params[:post_id]
      @answer_id = params[:answer_id]

      if @asker.author_id
        @author = User.find @asker.author_id
      end

      ## Activity Stream
      # asker_followers = Rails.cache.read()
        # @asker.follower_ids()

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @posts }
      end
    else
      redirect_to "/"
    end
  end

  def more
    post = Publication.find(params[:last_post_id])
    puts post.to_json
    if params[:id].to_i > 0
      @asker = User.asker(params[:id])
      @publications = @asker.publications.where("updated_at < ? and id != ? and published = ?", post.created_at, post.id, true).order("updated_at DESC").limit(5).includes(:question => :answers)
    else
      @publications = Publication.where("updated_at < ? and id != ? and published = ?", post.created_at, post.id, true).order("updated_at DESC").limit(5).includes(:question => :answers)
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
    finished("question activity", {:reset => false})
    render :json => Post.app_response(current_user, params["asker_id"], params["post_id"], params["answer_id"])
  end

  def manager_response
    asker = User.asker(params[:asker_id])
    user_post = Post.find(params[:in_reply_to_post_id])
    correct = (params[:correct].nil? ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil)
    conversation = user_post.conversation || Conversation.create(:post_id => user_post.id, :user_id => asker.id ,:publication_id => params[:publication_id])
    if params[:interaction_type] == "4"
      dm = params[:message].gsub("@#{params[:username]}", "")
      user_post.update_attribute(:correct, correct)
      response_post = Post.dm(asker, params[:message].gsub("@#{params[:username]}", ""), nil, nil, user_post, user_post.user, conversation.id)
    else
      tweet = params[:message].gsub("@#{params[:username]}", "")
      if params[:publication_id] and params[:correct]
        pub = Publication.find(params[:publication_id].to_i)
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
        response_post = Post.tweet(asker, tweet, {
          :reply_to => params[:username], 
          :long_url => long_url, 
          :interaction_type => 2, 
          :conversation_id => conversation.id,
          :in_reply_to_post_id => params[:in_reply_to_post_id], 
          :in_reply_to_user_id => params[:in_reply_to_user_id], 
          :link_to_parent => false,
          :resource_url => resource_url,
          :wisr_question => wisr_question
        })

        # Check for followup test completion
        Post.trigger_split_test(params[:in_reply_to_user_id], 'mention reengagement') if Post.joins(:conversation).where("posts.intention = ? and posts.in_reply_to_user_id = ? and conversations.publication_id = ?", 'incorrect answer follow up', params[:in_reply_to_user_id], params[:publication_id].to_i).present?
        # Check for reengage last week inactive test completion
        Post.trigger_split_test(params[:in_reply_to_user_id], 'reengage last week inactive') if Post.where("in_reply_to_user_id = ? and intention = ?", params[:in_reply_to_user_id], 'reengage last week inactive').present?

        Mixpanel.track_event "answered", {
          :distinct_id => params[:in_reply_to_user_id],
          :time => user_post.created_at.to_i,
          :account => asker.twi_screen_name,
          :source => params[:s]
        }
      else         
        response_post = Post.tweet(asker, tweet, {
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
    post_to_link = Post.find(params[:post_id])
    puts Publication.find(params[:link_to_pub_id]).to_json
    post_to_link_to = Publication.find(params[:link_to_pub_id]).posts.last
    post_to_link.update_attribute(:in_reply_to_post_id, post_to_link_to.id)
    render :json => [post_to_link, post_to_link_to]
  end

  def manage
    @asker = User.asker(params[:id])
    @posts = Post.where("requires_action = ? and in_reply_to_user_id = ? and (spam is null or spam = ?) and user_id not in (?)", true, params[:id], false, User.askers.collect(&:id)).order("created_at DESC")
    @questions = @asker.publications.where(:published => true).order("created_at DESC").includes(:question => :answers).limit(100)
    publication_ids = @asker.publications.select(:id).where(:published => true)
    @question_count = publication_ids.size
    @questions_answered = Post.where("in_reply_to_user_id = ? and correct is not null", params[:id]).count
    @followers = Stat.where(:asker_id => @asker.id).order('date DESC').limit(1).first.try(:total_followers) || 0    
    @engagements = {}
    @conversations = {}
    @posts.each do |p|
      @engagements[p.id] = p
      parent = p.parent
      @conversations[p.id] = {:posts => [], :answers => [], :users => {}}
      @conversations[p.id][:users][p.user.id] = p.user if @conversations[p.id][:users][p.user.id].nil?
      pub_id = nil
      while parent
        if parent.in_reply_to_user_id == @asker.id or parent.user_id == @asker.id
          @conversations[p.id][:posts] << parent
          @conversations[p.id][:users][parent.user.id] = parent.user if @conversations[p.id][:users][parent.user.id].nil?
          pub_id = parent.publication_id unless parent.publication_id.nil?
        end
        parent = parent.parent
      end
      p.text = p.parent.text if p.interaction_type == 3
      @conversations[p.id][:answers] = Publication.find(pub_id).question.answers unless pub_id.nil?
    end
    @leaders = User.leaderboard(params[:id])
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]

    # badge assignment data
    user_ids = @engagements.map{|k,v| v.user_id}.uniq
    @earned_badges_by_user = User.joins(:badges).where("users.id in (?)", user_ids).group_by{|u| u.id}
    @badges = Badge.where(:asker_id => @asker.id)
    @correct_answer_count_by_user = User.where("users.id in (?)", user_ids)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @posts }
    end
  end

  # def get_split_dm_response
  #   ab_user.set_id(params[:user_id])
  #   ab_user.confirm_js("WISR app", '')
  #   res = ab_test("dm reengagement", "Nudge", "No Nudge")
  #   render :text => res, :status => 200
  # end

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
