class FeedsController < ApplicationController
  before_filter :admin?, :only => [:manage]

  def index
    redirect_to "/feeds/2" unless User.askers.blank?
  end

  def show
    @asker = User.asker(params[:id])
    if @asker
      @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID != ?", @asker.id).sample(3)
      @publications = @asker.publications.where(:published => true).order("created_at DESC").limit(15).includes(:question => :answers)
      @leaders = User.leaderboard(params[:id])
      if current_user
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
    post = Publication.find(params[:last_post_id])
    publications = User.asker(params[:id]).publications.where("CREATED_AT < ? AND ID != ? AND PUBLISHED = ?", post.created_at, post.id, true).order("created_at DESC").limit(5).includes(:question => :answers)
    publication_ids = publications.collect(&:id)
    if current_user
      responses = Conversation.where(:user_id => current_user.id, :post_id => Post.select(:id).where(:provider => "twitter", :publication_id => publication_ids).collect(&:id), :publication_id => publication_ids).includes(:posts).group_by(&:publication_id)
    else
      responses = []
    end    
    render :json => {:publications => publications.as_json(:include => {:question => {:include => :answers}}), :responses => responses.as_json(:include => :posts)}
  end

  def scores
    @scores = User.get_top_scorers(params[:id])
  end

  def respond_to_question
    render :json => Post.app_response(current_user, params["asker_id"], params["post_id"], params["answer_id"])
  end

  def tweet
    @asker = User.asker(params[:asker_id])
    @user_post = Post.find(params[:in_reply_to_post_id])
    correct = params[:correct]=='null' ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil
    pub = Publication.find(params[:publication_id].to_i)
    post = pub.posts.where(:provider => "twitter").first
    @user_post.update_responded(correct, params[:publication_id].to_i, pub.question_id, params[:asker_id])
    long_url = nil
    long_url = "#{URL}/feeds/#{params[:asker_id]}/#{params[:publication_id]}" unless params[:publication_id].nil?
    render :json => Post.tweet(@asker, params[:tweet], '', params[:username], long_url, 
                 'mention reply', nil, nil,
                 nil, params[:in_reply_to_post_id], 
                 params[:in_reply_to_user_id], false, 
                 (correct.nil? ? "#{URL}/posts/#{post.id}/refer" : nil))
  end

  def link_to_post
    answer = Post.find(params[:post_id])
    post = Post.find(params[:link_to_post_id])
    answer.update_attributes(:in_reply_to_post_id => post.id, :engagement_type => 'mention reply')
    render :nothing => true
  end

  def manage
    @asker = User.asker(params[:id])
    @posts = Post.where(:responded_to => false, :in_reply_to_user_id => params[:id])
    #@questions = @asker.publications.where(:published => true).order("created_at DESC").limit(15).map{|pub| pub.question}
    @questions = @asker.posts.where("publication_id is not null").order("created_at DESC").limit(15).delete_if{|p| p.publication.nil?}.map{|post| [post.id, post.publication.question, post.publication.question.answers]}
    @questions.each {|q| puts q[1].inspect}
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

end
