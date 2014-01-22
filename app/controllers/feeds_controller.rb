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

  def index_with_search 
    @askers = Asker.where(published: true).order("id ASC")  
    render 'index_with_search'
  end

  def search
    @query = params['query']
    questions = Question.where("text ilike ?", "%#{@query}%").where("status = 1").order('RANDOM()').limit 200
    topics = Topic.includes(:users).where("name ilike ?", "%#{@query}%")

    _publications = Publication.select(["question_id", "max(id) AS id"])\
      .where("question_id IN (?)", questions.collect(&:id)).group('question_id').order('id DESC') #.limit 25
    @publications = Publication.includes(:asker).where('id in (?)', _publications.collect(&:id)).order('created_at DESC')
    
    @suggested_askers = @publications.group_by{|o| o.asker_id}.sort_by {|k, v| v.count}.reverse\
      .map{|k,v|v.first.asker}
    @suggested_askers += topics.collect(&:users).flatten.uniq

    render json: @suggested_askers.to_json
  end

  def show
    return if show_redirect

    if current_user
      show_template
    elsif !current_user and params[:q] == "1" and @asker
      redirect_to user_omniauth_authorize_path(:twitter, :feed_id => @asker.id, :q => 1, :use_authorize => false)
    else # post_yield
      template = Rails.cache.fetch("wisr.com/feeds/#{@asker.id}", expires_in: [14,15,16].sample.minutes, race_condition_ttl: 60) do
        show_template true 
      end

      if params[:post_id]
        post_yield_template = Rails.cache.fetch("feeds/_publication/#{params[:post_id]}", expires_in: 24.hours, race_condition_ttl: 60) do
          publication = Publication.recent_by_asker_and_id @asker.id, params[:post_id]
          render_to_string "feeds/_publication", layout: false, locals: {publication: publication, post_id: params[:post_id], answer_id: params[:answer_id]}
        end
        template = template.sub("<!--post_yield-->", post_yield_template)
        render text: template
        return
      end
      render text: template
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

  def more
    publication = Publication.includes(:posts).find(params[:last_post_id])
    if params[:id].to_i > 0
      @asker = User.asker(params[:id])
      @publications = @asker.publications.includes(:posts).where("publications.created_at < ? and publications.id != ? and publications.published = ? and posts.interaction_type = 1", publication.created_at, publication.id, true).order("posts.created_at DESC").limit(5).includes(:question => :answers)
    else  
      post = publication.posts.where("interaction_type = 1").order("posts.created_at DESC").limit(1).first
      if params[:filtered] == 'true'
        @publications = Publication.includes([:asker, :posts, :question => [:answers, :user]])\
          .published\
          .where("asker_id in (?)", current_user.follows.collect(&:id))\
          .where("posts.created_at < ?", post.created_at)\
          .where("publications.id != ?", publication.id)\
          .where("posts.interaction_type = 1")
          .order("posts.created_at DESC")\
          .limit(5)
      else
        @publications = Publication.includes(:posts).where("posts.created_at < ? and publications.id != ? and publications.published = ? and posts.interaction_type = 1", post.created_at, publication.id, true).order("posts.created_at DESC").limit(5).includes(:question => :answers)
      end
    end

    @responses = []
    if current_user     
      @responses = Conversation.where(:user_id => current_user.id, :post_id => Post.select(:id).where(:provider => "twitter", :publication_id => @publications.collect(&:id)).collect(&:id)).includes(:posts).group_by(&:publication_id) 
    end
    
    posts = Post.select([:id, :created_at, :publication_id]).where(:provider => "twitter", :publication_id => @publications.collect(&:id)).order("created_at DESC")
    
    @actions = post_pub_map = {}
    posts.each { |post| post_pub_map[post.id] = post.publication_id }
    
    Post.select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at]).where(:in_reply_to_post_id => posts.collect(&:id)).order("created_at ASC").includes(:user).group_by(&:in_reply_to_post_id).each do |post_id, post_activity|
      @actions[post_pub_map[post_id]] = []
      post_activity.each do |action|
        @actions[post_pub_map[post_id]] << {
          :user => {
            :id => action.user.id,
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

    @request_email = false
    if (current_user.email.blank? and (current_user.last_email_request_at.nil? or current_user.last_email_request_at < (Time.now - 30.days)))
      @request_email = true
      current_user.touch(:last_email_request_at)
    end

    render :partial => "conversation"
  end

  def link_to_post
    if params[:link_to_pub_id] == "0"
      post = Post.find(params[:post_id])
      post.update_attributes in_reply_to_question_id: nil, in_reply_to_post_id: nil
      render :json => post
    else
      post_to_link = Post.find(params[:post_id])
      publication = Publication.find(params[:link_to_pub_id])
      question = publication.question
      root_post = publication.posts.last

      post_to_link_to = publication.posts.where("in_reply_to_user_id is null").last
      
      conversation = Conversation.create(:post_id => root_post.id, :user_id => post_to_link.user_id ,:publication_id => publication.id)
      post_to_link.update_attributes({
        :in_reply_to_post_id => post_to_link_to.id,
        :in_reply_to_question_id => question.id,
        :conversation_id => conversation.id
      })

      Post.grader.grade post_to_link

      #add manually linked label to have training data for auto-linking
      tag = Tag.find_or_create_by(name: "manually-linked")
      tag.posts << post_to_link

      render :json => [post_to_link, post_to_link_to]
    end
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

  # generates html generic feed - ie. /feeds/18
  def show_template as_string = false
    # publications, posts and user responses
    @publications = Publication.recent_by_asker(@asker)
    posts = Publication.recent_publication_posts_by_asker(@asker, @publications)

    # user specific responses
    @responses = (current_user ? Conversation.where(:user_id => current_user.id, :post_id => posts.collect(&:id)).includes(:posts).group_by(&:publication_id) : [])

    # question activity
    actions = Publication.recent_responses_by_asker(@asker, posts)
    @actions = Post.recent_activity_on_posts(posts, actions) # this should be combined w/ above method

    # inject requested publication from params, render twi card
    @request_mod = false
    if params[:post_id] and current_user
      @post_id = params[:post_id]
      @answer_id = params[:answer_id]
      @requested_publication = @asker.publications.published.where(id: params[:post_id]).first
      if @requested_publication.present?
        @publications.reverse!.push(@requested_publication).reverse! unless @requested_publication.blank? or @publications.include?(@requested_publication)   
        question = @requested_publication.question
        @request_mod = true if current_user and question.needs_feedback? and question.question_moderations.active.where(user_id: current_user.id).blank?
      end
    end

    @author = User.find @asker.author_id if @asker.author_id

    @question_form = ((params[:question_form] == "1" or params[:q] == "1") ? true : false)
    as_string ? (return render_to_string(:show)) : render(:show)
  end
end
