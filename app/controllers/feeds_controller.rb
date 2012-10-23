class FeedsController < ApplicationController
  before_filter :admin?, :only => [:manage]

  def index
    redirect_to "/feeds/2" unless User.askers.blank?
  end

  def show
    @asker = User.asker(params[:id])
    if @asker
      @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID != ? AND published = ?", @asker.id, true).sample(3)
      # @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID in (?)", ACCOUNT_DATA[@asker.id][:retweet]).sample(3)
      @publications = @asker.publications.where(:published => true).order("created_at DESC").limit(15).includes(:question => :answers)

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

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @posts }
      end
    else
      redirect_to "/feeds/2"
    end
  end

  def more
    @asker = User.asker(params[:id])
    post = Publication.find(params[:last_post_id])
    @publications = User.asker(params[:id]).publications.where("CREATED_AT < ? AND ID != ? AND PUBLISHED = ?", post.created_at, post.id, true).order("created_at DESC").limit(5).includes(:question => :answers)
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
        response_post = Post.tweet(asker, tweet, {
          :reply_to => params[:username], 
          :long_url => long_url, 
          :interaction_type => 2, 
          :conversation_id => conversation.id,
          :in_reply_to_post_id => params[:in_reply_to_post_id], 
          :in_reply_to_user_id => params[:in_reply_to_user_id], 
          :link_to_parent => false,
          :resource_url => (correct.nil? ? "#{URL}/posts/#{post.id}/refer" : nil)
        })
        if Post.joins(:conversation).where("intention = ? and in_reply_to_user_id = ? and conversation.publication_id = ?", 'reengage', params[:in_reply_to_user_id], params[:publication_id].to_i)
          Post.trigger_split_test(params[:in_reply_to_user_id], 'mention reengagement')
        end
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
    @questions = @asker.publications.where(:published => true).order("created_at DESC").includes(:question => :answers).limit(32)
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

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @posts }
    end
  end

  def get_split_dm_response
    puts "get split dm response for user #{params[:user_id]}"
    ab_user.set_id(params[:user_id])
    res = ab_test("dm reengagement", "Nudge", "No Nudge")
    render :text => res, :status => 200
  end

end
