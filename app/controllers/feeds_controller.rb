class FeedsController < ApplicationController
  def index
    redirect_to "/feeds/#{User.askers.first.id}" unless User.askers.blank?
  end

  def show
    @asker = User.asker(params[:id])
    @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID is not ?", @asker.id).sample(3)
    @publications = @asker.publications.where(:published => true).order("created_at DESC").limit(15).includes(:question => :answers)
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
  end

  def more
    post = Publication.find(params[:last_post_id])
    publications = User.asker(params[:id]).publications.where("CREATED_AT < ? AND ID IS NOT ?", post.created_at, post.id).order("created_at DESC").limit(5).includes(:question => :answers)
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

  def respond
    render :json => Post.app_response(current_user, params["asker_id"], params["post_id"], params["answer_id"])
  end
end
