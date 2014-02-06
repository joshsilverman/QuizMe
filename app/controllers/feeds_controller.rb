class FeedsController < ApplicationController
  prepend_before_filter :check_for_authentication_token, :only => [:show]
  before_filter :authenticate_user!, :except => [:index, :index_with_search, :show, :stream, :more, :search] 
  before_filter :admin?, :only => [:manager_response]
  before_filter :set_session_variables, :only => [:show]

  def index
    @index = true
    @asker = User.find(1)
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]    
    @askers = Asker.where(published: true).order("id ASC")
    @wisr = User.find(8765)
    @directory = {}
    @publications = Publication.recent
    @responses = []
    
    @askers.each do |asker| 
      next unless ACCOUNT_DATA[asker.id]
      (@directory[ACCOUNT_DATA[asker.id][:category]] ||= []) << asker 
    end

    posts = Publication.recent_publication_posts(@publications)
    @actions = Post.recent_activity_on_posts(
      posts, 
      Publication.recent_responses(posts))

    if current_user
      @responses = Conversation.where(
          :user_id => current_user.id, 
          :post_id => posts.collect(&:id))
        .includes(:posts)
        .group_by(&:publication_id)
    end

    render 'index'
  end

  def show
    respond_to do |format|
      format.html { show_redirect }
      format.json do 
        publications = Publication.published
          .order(created_at: :desc).limit(10)

        render json: publications.to_json 
      end
    end
  end

  def stream(user_followers = [])
    posts = Post.includes(:user, :in_reply_to_question, :in_reply_to_user)
      .where('in_reply_to_question_id IS NOT NULL')
      .where(intention: 'respond to question')
      .where(in_reply_to_user_id: Asker.ids)
      .order(id: :desc).limit(50).to_a

    filtered_posts = []
    posts.each_with_index do |post, i|
      prev_post_user_id = posts[i - 1].try(:user_id)
      next if prev_post_user_id == post.user_id

      filtered_posts << {
        created_at: post.created_at,
        in_reply_to_question: {
          id: post.in_reply_to_question.id,
          text: post.in_reply_to_question.text
        },
        user: {
          twi_screen_name: post.user.twi_screen_name,
          twi_profile_img_url: post.user.twi_profile_img_url
        }
      }

      break if filtered_posts.count == 5
    end

    render json: filtered_posts
  end

  def respond_to_question
    publication = Publication.find(params[:publication_id])
    @question_asker = Asker.find(params[:asker_id])
    answer = Answer.includes(:question).find(params[:answer_id])

    if params[:publication_id] == session[:reengagement_publication_id] and session[:referring_user] and referring_user = User.find_by_twi_screen_name(session[:referring_user])
      post = @question_asker.posts.reengage_inactive.where("publication_id = ? and in_reply_to_user_id = ?", params[:publication_id], referring_user.id).order("created_at DESC").limit(1).first
    else
      post = answer.question.posts.statuses.order("created_at DESC").limit(1).first
    end
    post = Post.statuses.where(:publication_id => publication.id).order("created_at DESC").limit(1).first unless post

    # Create conversation for posts
    @conversation = Conversation.create({
      :user_id => current_user.id,
      :post_id => post.id,
      :publication_id => publication.id
    })
    
    user_post = current_user.app_answer(@question_asker, post, answer, { :conversation_id => @conversation.id, :in_reply_to_question_id => publication.question_id, :post_to_twitter => false })
    @question_asker.app_response(user_post, answer.correct, { :conversation_id => @conversation.id, :post_to_twitter => false, :link_to_parent => true }) if user_post

    head :success
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

  private

  def show_redirect
    redirect_called = false

    if params[:subject]
      @asker = Asker.find_by_subject_url params[:subject]
    else
      @asker = Asker.find(params[:id])
      redirect_url  = "/#{@asker.subject_url}"
      redirect_url += "/#{params[:post_id]}" if params[:post_id]
      redirect_url += "?#{request.env['QUERY_STRING']}" if request.env['QUERY_STRING']

      redirect_to redirect_url, status: :moved_permanently
      redirect_called = true
    end

    if @asker.nil?
      redirect_to '/' 
      redirect_called = true
    end

    redirect_called
  end
end