class FeedsController < ApplicationController
  def index
    redirect_to "/feeds/#{User.askers.first.id}" unless User.askers.blank?
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
    render :json => Post.tweet(@asker, params[:tweet], '', params[:username], long_url, 
                 engagement_type, link_type, conversation_id,
                 publication_id, in_reply_to_post_id, 
                 in_reply_to_user_id, link_to_parent)
  end

  def manage
    # redirect_to "/feeds/#{params[:id]}" unless current_user.role == "asker"
    @asker = User.asker(params[:id])
    # @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID != ?", @asker.id).sample(3)
    @posts = Post.where(:responded_to => false, :in_reply_to_user_id => params[:id])
    @engagements = {}
    @posts.each do |p|
      if p.in_reply_to_post_id.nil?
        @engagements[p.id] = [p, []] if @engagements[p.id].nil?
      else
        parent = p.parent
        @engagements[parent.id]  = [parent, []] if @engagements[parent.id].nil?
        @engagements[parent.id][1] << p
      end
    puts @engagements
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
