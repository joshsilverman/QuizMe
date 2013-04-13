class FeedsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :unauth_show, :activity_stream, :more, :mod_manage, :search]
  before_filter :unauthenticated_user!, :only => [:unauth_show]
  before_filter :moderator?, :only => [:mod_manage, :moderator_response]
  before_filter :admin?, :only => [:manage, :manager_response]
  before_filter :set_session_variables, :only => [:show]

  caches_action :unauth_show, :expires_in => 10.minutes, :cache_path => Proc.new { |c| c.params }

  def index
    @index = true
    @asker = User.find(1)
    @directory = {}
    @wisr = User.find(8765)
    Asker.where("published = ?", true).each do |asker| 
      next unless ACCOUNT_DATA[asker.id]
      (@directory[ACCOUNT_DATA[asker.id][:category]] ||= []) << asker 
    end

    @askers = Asker.where(published: true).limit 12
  end

  def search
    questions_by_asker_id = Question.where("text ilike ?", "%#{params['query']}%")\
      .where("status = 1")\
      .group_by{|q|q.created_for_asker_id}
    asker_id = nil
    questions = []
    questions_by_asker_id.each do |k,v|
      if v.count > questions.count
        asker_id = k
        questions = v
      end
    end
    # Post.where("in_reply_to_question_id IN (?)", questions.collect(&:id)).group('in_reply_to_question_id').count

    @query = params['query']
    @asker = Asker.find asker_id
    @question_count, @questions_answered, @followers = @asker.get_stats

    _publications = Publication.select(["question_id", "max(id) AS id"])\
      .where("question_id IN (?)", questions.collect(&:id)).group('question_id').order('id DESC').limit 25
    @publications = Publication.where('id in (?)', _publications.collect(&:id)).order('created_at DESC')

    _posts = Post.select(["publication_id", "max(id) AS id"])\
      .where("publication_id IN (?)", @publications.collect(&:id)).group('publication_id')
    posts = Post.where('id in (?)', _posts.collect(&:id)).order('created_at DESC')

    actions = Publication.recent_responses_by_asker(@asker, posts)
    @actions = Post.recent_activity_on_posts(posts, actions)
    @responses = (current_user ? Conversation.where(:user_id => current_user.id, :post_id => posts.collect(&:id)).includes(:posts).group_by(&:publication_id) : [])

    # misc
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]
    @author = User.find @asker.author_id if @asker.author_id

    # related
    @related = Asker.select([:id, :twi_name, :description, :twi_profile_img_url])\
      .where(:id => ACCOUNT_DATA.keys.sample(3)).all

    @question_form = ((params[:question_form] == "1" or params[:q] == "1") ? true : false)

    respond_to do |format|
      format.html { render :show }
      format.json { render json: @posts }
    end
  end

  # def search
  #   questions_by_asker_id = Question.where("text ilike ?", "%#{params['query']}%")\
  #     .where("status = 1")\
  #     .group_by{|q|q.created_for_asker_id}
  #   asker_id = nil
  #   questions = []
  #   questions_by_asker_id.each do |k,v|
  #     if v.count > questions.count
  #       asker_id = k
  #       questions = v
  #     end
  #   end
  #   # Post.where("in_reply_to_question_id IN (?)", questions.collect(&:id)).group('in_reply_to_question_id').count

  #   @query = params['query']
  #   @asker = Asker.find asker_id
  #   @question_count, @questions_answered, @followers = @asker.get_stats

  #   _publications = Publication.select(["question_id", "max(id) AS id"])\
  #     .where("question_id IN (?)", questions.collect(&:id)).group('question_id').order('id DESC').limit 25
  #   @publications = Publication.where('id in (?)', _publications.collect(&:id)).order('created_at DESC')

  #   _posts = Post.select(["publication_id", "max(id) AS id"])\
  #     .where("publication_id IN (?)", @publications.collect(&:id)).group('publication_id')
  #   posts = Post.where('id in (?)', _posts.collect(&:id)).order('created_at DESC')

  #   actions = Publication.recent_responses_by_asker(@asker, posts)
  #   @actions = Post.recent_activity_on_posts(posts, actions)
  #   @responses = (current_user ? Conversation.where(:user_id => current_user.id, :post_id => posts.collect(&:id)).includes(:posts).group_by(&:publication_id) : [])

  #   # misc
  #   @post_id = params[:post_id]
  #   @answer_id = params[:answer_id]
  #   @author = User.find @asker.author_id if @asker.author_id

  #   # related
  #   @related = Asker.select([:id, :twi_name, :description, :twi_profile_img_url])\
  #     .where(:id => ACCOUNT_DATA.keys.sample(3)).all

  #   @question_form = ((params[:question_form] == "1" or params[:q] == "1") ? true : false)

  #   respond_to do |format|
  #     format.html { render :show }
  #     format.json { render json: @posts }
  #   end
  # end

  def unauth_show
    show true
  end

  def show force = false
    if !current_user and params[:q] == "1" and params[:id]
      redirect_to user_omniauth_authorize_path(:twitter, :feed_id => params[:id], :q => 1, :use_authorize => false)
    elsif current_user.nil? and force == false
      redirect_to "/u#{request.fullpath}", params
    else
      if @asker = Asker.find(params[:id])

        # publications, posts and user responses
        @publications, posts = Publication.recently_published_by_asker(@asker)
        actions = Publication.recent_responses_by_asker(@asker, posts)

        # user specific responses
        @responses = (current_user ? Conversation.where(:user_id => current_user.id, :post_id => posts.collect(&:id)).includes(:posts).group_by(&:publication_id) : [])

        # question activity
        @actions = Post.recent_activity_on_posts(posts, actions)

        # inject requested publication from params, render twi card
        if params[:post_id]
          @requested_publication = @asker.publications.find(params[:post_id])
          @publications.reverse!.push(@requested_publication).reverse! unless @publications.include? @requested_publication
          @render_twitter_card = true
        else
          @render_twitter_card = false     
        end

        # stats
        @question_count, @questions_answered, @followers = @asker.get_stats
        
        # misc
        @post_id = params[:post_id]
        @answer_id = params[:answer_id]
        @author = User.find @asker.author_id if @asker.author_id

        # related
        @related = Asker.select([:id, :twi_name, :description, :twi_profile_img_url])\
          .where(:id => ACCOUNT_DATA.keys.sample(3)).all

        @question_form = ((params[:question_form] == "1" or params[:q] == "1") ? true : false)

        respond_to do |format|
          format.html { render :show }
          format.json { render json: @posts }
        end
      else
        redirect_to "/"
      end
    end
  end

  def activity_stream(user_followers = [])
    asker_ids = User.askers.collect(&:id)
    if current_user
      unless (user_followers = (Rails.cache.read("follower_ids:#{current_user.id}") || [])).present?
        user_followers = Post.twitter_request { current_user.twitter.follower_ids().ids }
        Rails.cache.write("follower_ids:#{current_user.id}", user_followers, :timeToLive => 2.days)
      end
    end

    @stream = []
    time_ago = 8.hours
    if user_followers.present?
      recent_posts = Post.not_spam.joins(:user)\
        .where("users.twi_user_id in (?) and users.id not in (?) and (posts.interaction_type = 3 or (posts.interaction_type = 2)) and posts.created_at > ? and conversation_id is not null", user_followers, asker_ids, time_ago.ago)\
        .order("created_at DESC")\
        .limit(5)\
        .includes(:conversation => {:publication => :question})
      recent_posts.group_by(&:user_id).each do |user_id, posts|
        next if posts.empty?
        post = posts.first
        next unless post.conversation and post.conversation.publication
        @stream << posts.shift
      end
    end
    if @stream.size < 5
      users = User.where("users.last_answer_at is not null and users.id not in (?)", (asker_ids))\
        .order("users.last_answer_at DESC").limit(10)
        
      users = users.reject{|u| user_followers.include? u.id} if user_followers.present?

      users.each do |user| 
        post = user.posts.not_spam.includes(:conversation => :publication).where("posts.interaction_type = 2").order("created_at DESC").limit(1).first
        next unless post and post.conversation and post.conversation.publication
        @stream << post unless post.blank?
        break if @stream.size >= 5
      end
    end
    @stream.sort! { |a, b| b.created_at <=> a.created_at }
    render :partial => "stream"
  end

  def more
    publication = Publication.includes(:posts).find(params[:last_post_id])
    if params[:id].to_i > 0
      @asker = User.asker(params[:id])
      @publications = @asker.publications.includes(:posts).where("publications.created_at < ? and publications.id != ? and publications.published = ? and posts.interaction_type = 1", publication.created_at, publication.id, true).order("posts.created_at DESC").limit(5).includes(:question => :answers)
    else
      post = publication.posts.where("interaction_type = 1").order("posts.created_at DESC").limit(1).first
      @publications = Publication.includes(:posts).where("posts.created_at < ? and publications.id != ? and publications.published = ? and posts.interaction_type = 1", post.created_at, publication.id, true).order("posts.created_at DESC").limit(5).includes(:question => :answers)
    end

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

  def scores
    @scores = User.get_top_scorers(params[:id])
  end

  def respond_to_question post_to_twitter = false
    publication = Publication.find(params[:publication_id])
    @question_asker = Asker.find(params[:asker_id])
    answer = Answer.find(params[:answer_id])

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

    # Rails.cache.delete "publications_recent_responses_by_asker_#{@question_asker.id}"

    render :partial => "conversation"
  end

  def moderator_response
    user_post = Post.find(params[:in_reply_to_post_id])
    correct = (params[:correct].nil? ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil)
    user_post.update_attributes(moderator_id: current_user.id, autocorrect: correct)
    render status: 200, nothing: true
  end

  def manager_response
    asker = Asker.find(params[:asker_id])
    user_post = Post.find(params[:in_reply_to_post_id])
    user = user_post.user
    correct = (params[:correct].nil? ? nil : params[:correct].match(/(true|t|yes|y|1)$/i) != nil)
    tell = (params[:tell].nil? ? nil : params[:tell].match(/(true|t|yes|y|1)$/i) != nil)

    unless conversation = user_post.conversation
      post_id = user_post.parent.try(:id) || user_post.id
      conversation = Conversation.create(:post_id => post_id, :user_id => asker.id, :publication_id => params[:publication_id])
      conversation.posts << user_post
    end
    root_post = conversation.post

    if params[:interaction_type] == "4"
      if correct.nil?
       response_text = params[:message]
        if response_text == "Refer a friend?"
          response_text = Post.create_split_test(user.id, "Refer a friend script (follower joins)", 
            "Do you have any friends/classmates that would also be interested?",
            "Could you share with a couple of friends/classmates please?"
          )
        else
          response_text = params[:message].gsub("@#{params[:username]}", "")
        end

        response_post = Post.delay.dm(asker, user, response_text, {
          :conversation_id => conversation.id,
          :intention => params[:message] == "Refer a friend?" ? 'refer a friend' : nil
        })
      else
        if tell
          answer_text = Answer.where("question_id = ? and correct = ?", user_post.in_reply_to_question_id, true).first.text
          answer_text = "#{answer_text[0..77]}..." if answer_text.size > 80
          response_text = "I was looking for '#{answer_text}'"
        else
          response_text = asker.generate_response(correct, user_post.question, tell)
        end

        user_post.update_attribute(:correct, correct)

        # Will double count if we grade people again via DM
        Mixpanel.track_event "answered", {
          :distinct_id => params[:in_reply_to_user_id],
          :time => user_post.created_at.to_i,
          :account => asker.twi_screen_name,
          :type => "twitter",
          :in_reply_to => "new follower question DM"
        }

        user.update_user_interactions({
          :learner_level => "dm answer", 
          :last_interaction_at => user_post.created_at,
          :last_answer_at => user_post.created_at
        }) 

        response_post = Post.delay.dm(asker, user, response_text, {
          :conversation_id => conversation.id,
          :intention => params[:message] == "Refer a friend?" ? 'refer a friend' : nil,
          :intention => 'grade'
        })
      end
    else
      response_text = (params[:message].present? ? params[:message].gsub("@#{params[:username]}", "") : nil)
      if correct.nil?
        response_post = Post.delay.tweet(asker, response_text, {
          :reply_to => params[:username], 
          :interaction_type => 2, 
          :conversation_id => conversation.id,
          :in_reply_to_post_id => params[:in_reply_to_post_id], 
          :in_reply_to_user_id => params[:in_reply_to_user_id], 
          :link_to_parent => true
        })
      else
        response_post = asker.delay.app_response(user_post, correct, { 
          :response_text => response_text,
          :link_to_parent => root_post.is_question_post? ? false : true,
          :tell => tell,
          :conversation_id => conversation.id,
          :post_to_twitter => true,
          :manager_response => true,
          :quote_user_answer => root_post.is_question_post? ? true : false,
          :intention => 'grade'
        })
      end
    end

    user_post.update_attributes({:requires_action => (['new content', 'ask a friend', 'ugc'] & user_post.tags.collect(&:name)).present?, :conversation_id => conversation.id}) if response_post
    render :json => response_post.present?
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
      tag = Tag.find_or_create_by_name "manually-linked"
      tag.posts << post_to_link

      render :json => [post_to_link, post_to_link_to]
    end
  end

  def mod_manage
    @posts = Post.includes(:tags, :conversation).linked_box.not_dm.\
      joins("INNER JOIN posts as parents on parents.id = posts.in_reply_to_post_id").\
      where("parents.question_id IS NOT NULL").\
      where("posts.in_reply_to_user_id IN (?)", current_user.follows.where("role = 'asker'")).\
      where("posts.moderator_id IS NULL").order("random()").limit(10).\
      sort_by{|p| p.created_at}.reverse

    @questions = []
    @engagements, @conversations = Post.grouped_as_conversations @posts
    @asker = User.find 8765
    @oneinbox = true
    @askers_by_id = Hash[*Asker.select([:id, :twi_screen_name]).map{|a| [a.id, a.twi_screen_name]}.flatten]
    @asker_twi_screen_names = Asker.askers_with_id_and_twi_screen_name.sort_by! { |a| a.twi_screen_name.downcase }.each { |a| a.twi_screen_name = a.twi_screen_name.downcase }

    render :manage
  end

  def manage
    #base selection
    @posts = Post.includes(:tags, :conversation)
    if params[:id]
      @asker = Asker.find params[:id]
      @posts = @posts.where("posts.in_reply_to_user_id = ?", params[:id])
    end

    @linked_box_count = @posts.linked_box.count
    @unlinked_box_count = @posts.unlinked_box.count
    @autocorrected_box_count = @posts.autocorrected_box.count

    #filter for retweet, spam, starred
    if params[:filter] == 'retweets'
      @posts = @posts.retweet_box.not_spam.order("posts.created_at DESC")
    elsif params[:filter] == 'spam'
      @posts = @posts.spam_box.order("posts.created_at DESC")
    elsif params[:filter] == 'ugc'
      @posts = @posts.ugc_box.not_spam.order("posts.created_at DESC")
    elsif params[:filter] == 'feedback'
      @posts = @posts.feedback_box.not_spam.order("posts.created_at DESC")
    elsif params[:filter] == 'tutor'
      @posts = @posts.tutor_box.not_spam.order("posts.created_at DESC")
    elsif params[:filter] == 'linked'
      @posts = @posts.linked_box.not_spam.order("posts.created_at ASC")
    elsif params[:filter] == 'unlinked'
      @posts = @posts.unlinked_box.not_spam.order("posts.created_at ASC")
    elsif params[:filter] == 'content'
      @posts = @posts.content_box.not_spam.order("posts.created_at ASC")
    elsif params[:filter] == 'friend'
      @posts = @posts.friend_box.not_spam.order("posts.created_at ASC")            
    elsif params[:filter] == 'all'
      @posts = @posts.all_box.not_spam.order("posts.created_at DESC")
    else
      @posts = @posts.autocorrected_box.not_spam.order("posts.created_at ASC")
    end

    @tags = Tag.all
    @asker_twi_screen_names = Asker.askers_with_id_and_twi_screen_name.sort_by! { |a| a.twi_screen_name.downcase }.each { |a| a.twi_screen_name = a.twi_screen_name.downcase }
    @nudge_types = NudgeType.all
    @posts = @posts.page(params[:page]).per(50)

    if @asker
      @questions = @asker.publications.where(:published => true)\
        .order("created_at DESC").includes(:question => :answers).limit(100)
      @engagements, @conversations = Post.grouped_as_conversations @posts, @asker
    else
      @questions = []
      @engagements, @conversations = Post.grouped_as_conversations @posts
      @asker = User.find 8765
      @oneinbox = true
      @askers_by_id = Hash[*Asker.select([:id, :twi_screen_name]).map{|a| [a.id, a.twi_screen_name]}.flatten]
    end
  end

  def refer_a_friend
    asker = Asker.find(params[:asker_id])
    twitter_user = Post.twitter_request { asker.twitter.user(params[:user_twi_screen_name]) }
    user = User.find_or_initialize_by_twi_user_id(twitter_user.id)
    user.update_attributes( 
      :twi_name => twitter_user.name,
      :name => twitter_user.name,
      :twi_screen_name => twitter_user.screen_name,
      :twi_profile_img_url => twitter_user.profile_image_url,
      :description => twitter_user.description.present? ? twitter_user.description : nil
    )

    if params[:type] == 'popular' and Post.where("intention = 'quiz a friend' and in_reply_to_user_id = ?", user.id).blank?
      question = asker.most_popular_question
      publication = question.publications.order("created_at DESC").first
    elsif params[:type] == 'ugc'
      question = User.find_by_twi_screen_name(params[:via]).questions.where("created_for_asker_id = ?", params[:asker_id]).last
      publication = question.publications.order("created_at DESC").first
    end    

    if question and publication
      response_post = Post.tweet(asker, question.text, {
        :reply_to => params[:user_twi_screen_name], 
        :interaction_type => 2,
        :intention => 'quiz a friend',
        :via => params[:via],
        :long_url => "#{URL}/feeds/#{asker.id}/#{publication.id}",
        :in_reply_to_user_id => user.id,
        :publication_id => publication.id,
        :question_id => question.id
      })  
      Mixpanel.track_event "quiz a friend", {
        :distinct_id => user.id,
        :asker => asker.twi_screen_name,
        :type => params[:type]
      }      
      render :json => response_post
    else
      render :nothing => true, :status => 403
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
end
