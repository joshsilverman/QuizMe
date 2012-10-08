class FeedsController < ApplicationController
  before_filter :admin?, :only => [:manage]

  def index
    redirect_to "/feeds/2" unless User.askers.blank?
  end

  def show
    @asker = User.asker(params[:id])
    if @asker
      # @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID in (?)", ACCOUNT_DATA[@asker.id][:retweet]).sample(3)
      @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID != ?", @asker.id).sample(3)
      @publications = @asker.publications.where(:published => true).order("created_at DESC").limit(15).includes(:question => :answers)
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
        @responses = Conversation.where(:user_id => current_user.id, :post_id => Post.select(:id).where(:provider => "twitter", :publication_id => @publications.collect(&:id)).collect(&:id)).includes(:posts).group_by(&:publication_id) 
      else
        @responses = []
      end
      @post_id = params[:post_id]
      @answer_id = params[:answer_id]

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
    puts 'bingo'
    bingo! 'answer_options_visible'
    render :json => Post.app_response(current_user, params["asker_id"], params["post_id"], params["answer_id"])
  end

  def manager_response
    puts "in manager tweet, params:"
    puts params.to_json
    asker = User.asker(params[:asker_id])
    user_post = Post.find(params[:in_reply_to_post_id])
    correct = (params[:correct].nil? ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil)
    conversation = user_post.conversation || Conversation.create(:post_id => user_post.id, :user_id => asker.id ,:publication_id => params[:publication_id])
    if params[:interaction_type] == "4"
      dm = params[:message].gsub("@#{params[:username]}", "")
      user_post.update_attribute(:correct, correct)
      Post.dm(asker, params[:message].gsub("@#{params[:username]}", ""), nil, nil, user_post, user_post.user, conversation.id)
    else
      puts "answer"
      tweet = params[:message].gsub("@#{params[:username]}", "")
      if params[:publication_id] and params[:correct]
        pub = Publication.find(params[:publication_id].to_i)
        post = pub.posts.where(:provider => "twitter").first
        user_post.update_responded(correct, params[:publication_id].to_i, pub.question_id, params[:asker_id])
        user_post.update_attribute(:correct, correct)
        long_url = (params[:publication_id].nil? ? nil : "#{URL}/feeds/#{params[:asker_id]}/#{params[:publication_id]}")
        response_post = Post.tweet(asker, tweet, '', params[:username], long_url, 
                     2, nil, conversation.id,
                     nil, params[:in_reply_to_post_id], 
                     params[:in_reply_to_user_id], false,
                     '', (correct.nil? ? "#{URL}/posts/#{post.id}/refer" : nil), nil)
      else
        puts "reply"
        response_post = Post.tweet(asker, tweet, '', params[:username], nil, 
                     2, nil, conversation.id,
                     nil, params[:in_reply_to_post_id], 
                     params[:in_reply_to_user_id], true, nil, nil, nil)      
      end
    end
    user_post.update_attributes({:responded_to => true, :conversation_id => conversation.id})
    render :json => response_post
  end

  def link_to_post
    post_to_link = Post.find(params[:post_id])
    post_to_link_to = Publication.find(params[:link_to_pub_id]).posts.last
    post_to_link.update_attribute(:in_reply_to_post_id, post_to_link_to.id)
    render :json => [post_to_link, post_to_link_to]
  end

  def manage
    @asker = User.asker(params[:id])
    @posts = Post.where("responded_to = ? and in_reply_to_user_id = ? and (spam is null or spam = ?) and user_id not in (?)", false, params[:id], false, User.askers.collect(&:id)).order("created_at DESC")
    @questions = @asker.publications.order("created_at DESC").includes(:question => :answers).limit(32)
    @engagements = {}
    @conversations = {}
    @posts.each do |p|
      @engagements[p.id] = p
      parent = p.parent
      @conversations[p.id] = {:posts => [], :answers => [], :users => {}}
      @conversations[p.id][:users][p.user.id] = p.user if @conversations[p.id][:users][p.user.id].nil?
      pub_id = nil
      while parent
        @conversations[p.id][:posts] << parent
        @conversations[p.id][:users][parent.user.id] = parent.user if @conversations[p.id][:users][parent.user.id].nil?
        pub_id = parent.publication_id unless parent.publication_id.nil?
        parent = parent.parent
      end
      p.text = p.parent.text if p.interaction_type == 3
      @conversations[p.id][:answers] = Publication.find(pub_id).question.answers unless pub_id.nil?
    end
    #@publications = @asker.publications.where(:id => Conversation.where(:id => conversation_ids).collect(&:publication_id), :published => true).order("created_at DESC").limit(15).includes(:question => :answers)
    #@publications = @asker.publications.where(:published => true).order("created_at DESC").limit(15).includes(:question => :answers)
    
    @leaders = User.leaderboard(params[:id])
    # if current_user
    #   @responses = Conversation.where(:user_id => current_user.id,
    #                                   :post_id => Post.select(:id).where(
    #                                                   :provider => "twitter",
    #                                                   :publication_id => @publications.collect(&:id)
    #                                                   ).collect(&:id)
    #                                   ).includes(:posts).group_by(&:publication_id) 
    # else
    #   @responses = []
    # end
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @posts }
    end
  end

  def get_abingo_dm_response
    puts params[:user_id]
    Abingo.identity = params[:user_id]
    response = nil
    ab_test("dm_reengage", ["No Prod", "Prod"], :conversion => "reengage") do |res|
      response = res
    end

    render :text => response, :status => 200
  end

end
