class FeedsController < ApplicationController
  def index

  end

  def show
    @asker = User.asker(params[:id])
    @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID is not ?", @asker.id).sample(3)
    ## GET just posted to twitter
    # @posts = Post.order("created_at DESC").limit(15).includes(:question => :answers).where(:provider => "twitter", :publication_id => publication_ids)
    @publications = @asker.publications.where(:published => true).order("created_at DESC").limit(15).includes(:question => :answers)
    publication_ids = @publications.collect(&:id)
    @conversations = Conversation.where(:user_id => current_user.id, :post_id => Post.select(:id).where(:provider => "twitter", :publication_id => publication_ids).collect(&:id)).includes(:posts)
    @conversations.each do |c|
      puts c.posts.to_json
    end
    # if current_user
      # @conversations = Conversation.where(:)
      # @responses = @publications.posts.where(:provider => "twitter")#.conversations.where(:user_id => current_user.id).includes(:posts)
      # puts @responses
    # end
    # @responses = Post.select([:text]).where()
    # @posts = @asker.posts.where(:provider => "app").order("created_at DESC").limit(15).includes(:question => :answers)
    # puts current_user.to_json
    # puts current_user.posts.to_json
    # @responses = current_user.posts.select([:text, :parent_id]).where(:parent_id => @posts.collect(&:parent_id)).group_by(&:parent_id)
    # @responses = Engagement.select([:text]).where(:user_id => current_user.id, :provider_post_id => @posts.collect(&:parent_id))
    # puts @responses.to_json
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @posts }
    end
  end

  def more
    post = Post.find(params[:last_post_id])
    render :json => User.asker(params[:id]).posts.where("CREATED_AT < ? AND ID IS NOT ? AND provider = 'app'", post.created_at, post.id).order(:created_at).limit(5).includes(:question => :answers).as_json(:include => {:question => {:include => :answers}})
  end

  def scores
    @scores = User.get_top_scorers(params[:id])
  end

  def respond
    render :text => Post.app_response(current_user, params["asker_id"], params["post_id"], params["answer_id"])
  end
end
