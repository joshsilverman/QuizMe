class FeedsController < ApplicationController
  def index

  end

  def show
    @asker = User.asker(params[:id])
    @related = User.select([:id, :twi_name, :description, :twi_profile_img_url]).askers.where("ID is not ?", @asker.id).sample(3)
    @publications = @asker.publications
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
    render :text => Post.respond_wisr(current_user, params["asker_id"], params["post_id"], params["answer_id"])
  end
end
