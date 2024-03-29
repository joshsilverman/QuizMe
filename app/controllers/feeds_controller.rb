class FeedsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:respond_to_question]
  prepend_before_filter :check_for_authentication_token, :only => [:show, :index]
  before_filter :authenticate_user!, :except => [:index, :index_with_search, :show, :stream, :more, :new]
  before_filter :admin?, :only => [:manager_response]
  before_filter :set_session_variables, :only => [:show]

  def index
    respond_to do |format|
      format.html do
        query_string = request.query_string.empty? ? "" : "?#{request.query_string}"
        url = "#{FEED_URL}#{query_string}"
        redirect_to url, status: 301
      end

      format.json.phone do
        offset = params['offset'] || 0
        followed_ids = current_user.wisr_follows.pluck(:followed_id)
        publication_scoped = Publication.where(asker_id: followed_ids)
        publications = publication_scoped.recent(offset)

        render json: publications.to_json
      end

      format.json.none do
        offset = params['offset'] || 0
        publications = Publication.recent(offset)

        render json: publications.to_json
      end
    end
  end

  def show
    respond_to do |format|
      format.html {
        redirected = show_redirect
        if !redirected
          url = "#{FEED_URL}#{request.fullpath}"
          redirect_to url, status: 301
        end
      }

      format.json do
        subject = params[:subject] || 'wisr'
        asker = Asker.find_by_subject_url subject
        offset = params['offset'] || 0

        publications_json = Publication.recent_by_asker_json(asker,
          params[:publication_id], offset)

        render json: publications_json
      end
    end
  end

  def new
    respond_to do |format|
      format.json do
        subject = params[:subject] || 'wisr'
        asker = Asker.find_by_subject_url subject
        offset = params['offset'] || 0

        if asker
          new_questions = Question
            .where(created_for_asker_id: asker.id)
            .where('text IS NOT NULL')
            .order(created_at: :desc)
            .includes(:user)
            .limit(10).offset(offset)

          render json: new_questions,
            each_serializer: QuestionAsPublicationSerializer,
            root: false
        else
          head 404
        end
      end
    end
  end

  def stream
    posts = Post.includes(:user, :in_reply_to_question, :in_reply_to_user)
      .where('in_reply_to_question_id IS NOT NULL')
      .where(intention: 'respond to question')
      .where(in_reply_to_user_id: Asker.ids)
      .order(id: :desc).limit(100).to_a

    filtered_posts = []
    posts.each_with_index do |post, i|
      prev_post_user_id = posts[i - 1].try(:user_id)
      next if prev_post_user_id == post.user_id
      next if post.user.twi_screen_name.nil?

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

    render json: filtered_posts.to_json
  end

  def respond_to_question
    @question_asker = Asker.find(params[:asker_id])
    answer = Answer.includes(:question).find(params[:answer_id])
    question = answer.question

    publication = Publication.find_by(id: params[:publication_id])
    publication ||= Publication.find_or_create_by_question_id question.id, params[:asker_id]

    if params[:publication_id] == session[:reengagement_publication_id] and session[:referring_user] and referring_user = User.find_by_twi_screen_name(session[:referring_user])
      post = @question_asker.posts.reengage_inactive
        .where("publication_id = ? and in_reply_to_user_id = ?",
          params[:publication_id], referring_user.id)
        .order("created_at DESC").first
    else
      post = answer.question.posts.statuses.order("created_at DESC").first
    end

    if !post
      post = Post.statuses
        .where(publication_id: publication.id)
        .order("created_at DESC")
        .limit(1).first
    end

    post ||= Post.create(
      publication_id: publication.id,
      question: question,
      user: @question_asker)

    @conversation = Conversation.create({
      :user_id => current_user.id,
      :post_id => post.id,
      :publication_id => publication.id})

    user_post = current_user.app_answer(@question_asker,
      post,
      answer,
      { conversation_id: @conversation.id,
        in_reply_to_question_id: publication.question_id,
        post_to_twitter: false })

    if user_post
      if request.variant and request.variant.include? :phone
        type = 'iPhone'
      else
        type = "web"
      end

      @question_asker.app_response(
        user_post,
        answer.correct, {
          conversation_id: @conversation.id,
          post_to_twitter: false,
          link_to_parent: true,
          type: type})
    end

    render json: user_post.correct
  end

  private

  def show_redirect
    redirect_called = false

    subject = params[:subject]

    if subject
      @asker = Asker.find_by_subject_url subject
    else
      @asker = Asker.find(params[:id])
      redirect_url  = "/#{@asker.subject_url}"

      if params[:publication_id]
        redirect_url += "/#{params[:publication_id]}"
      end

      if request.env['QUERY_STRING']
        redirect_url += "?#{request.env['QUERY_STRING']}"
      end

      redirect_to redirect_url, status: :moved_permanently
      redirect_called = true
    end

    if !current_user and params[:q] == "1" and @asker and !redirect_called
      redirect_to user_omniauth_authorize_path(:twitter,
        :feed_id => @asker.id,
        :q => 1,
        :use_authorize => false)

      redirect_called = true
    end

    if @asker.nil?
      redirect_to '/'
      redirect_called = true
    end

    redirect_called
  end
end
