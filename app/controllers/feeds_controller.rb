class FeedsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :index_with_search, :show, :unauth_show, :stream, :more, :search] 
  before_filter :unauthenticated_user!, :only => [:unauth_show] 
  before_filter :admin?, :only => [:manage, :manager_response]
  before_filter :set_session_variables, :only => [:show]

  caches_action :unauth_show, :expires_in => 15.minutes, :cache_path => Proc.new { |c| c.params.except(:s, :lt, :c, :t) }

  def index
    @index = true
    @asker = User.find(1)
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]
    @post_id = params[:post_id]
    @answer_id = params[:answer_id]    
    @askers = Asker.where(published: true).order("id ASC")
    
    if current_user
      if current_user.follows.present? and ab_test("logged in home page (=> advanced)", 'index', 'filtered index w/ activity') == 'filtered index w/ activity' # logged in user, new homepage
        @publications = Publication.includes([:asker, :posts, :question => [:answers, :user]])\
          .published\
          .where("asker_id in (?)", current_user.follows.collect(&:id))\
          .where("posts.interaction_type = 1", true)\
          .where("posts.created_at > ?", 1.days.ago)\
          .order("posts.created_at DESC")\
          .limit(15)
        posts = Post.select([:id, :created_at, :publication_id])\
          .where("publication_id in (?)", @publications.collect(&:id))\
          .order("created_at DESC")

        @subscribed = Asker.includes(:related_askers).where("id in (?)", current_user.follows.collect(&:id))

        if Post.create_split_test(current_user.id, 'other feeds panel shows related askers (=> regular)', 'false', 'true') == 'false'
          @related = Asker.select([:id, :twi_name, :description, :twi_profile_img_url])\
            .where(:id => ACCOUNT_DATA.keys.sample(3)).all          
        else
          @related = @subscribed.collect {|a| a.related_askers }.flatten.uniq.reject {|a| @subscribed.include? a }.sample(3)
        end 
        
        @responses = Conversation.where(:user_id => current_user.id, :post_id => posts.collect(&:id)).includes(:posts).group_by(&:publication_id)      
        @actions = Post.recent_activity_on_posts(posts, Publication.recent_responses(posts))
        
        render 'index_with_activity' 
      else # logged in user, old homepage
        @wisr = User.find(8765)
        @publications, posts = Publication.recently_published

        @responses = []
        @directory = {}
        Asker.where("published = ?", true).each do |asker| 
          next unless ACCOUNT_DATA[asker.id]
          (@directory[ACCOUNT_DATA[asker.id][:category]] ||= []) << asker 
        end
        @question_count, @questions_answered, @followers = Rails.cache.fetch "stats_for_index", :expires_in => 1.day, :race_condition_ttl => 15 do
          question_count = Publication.published.size
          questions_answered = Post.answers.size
          followers = Relationship.select("DISTINCT follower_id").size 
          [question_count, questions_answered, followers]
        end  
        @responses = Conversation.where(:user_id => current_user.id, :post_id => posts.collect(&:id)).includes(:posts).group_by(&:publication_id)
        @actions = Post.recent_activity_on_posts(posts, Publication.recent_responses(posts))

        render 'index'        
      end
    else
      if ab_test("New Landing Page", 'index', 'index_with_search') == 'index' # logged out user, old homepage
        @wisr = User.find(8765)
        @publications, posts = Publication.recently_published

        @responses = []
        @directory = {}
        Asker.where("published = ?", true).each do |asker| 
          next unless ACCOUNT_DATA[asker.id]
          (@directory[ACCOUNT_DATA[asker.id][:category]] ||= []) << asker 
        end
        @question_count, @questions_answered, @followers = Rails.cache.fetch "stats_for_index", :expires_in => 1.day, :race_condition_ttl => 15 do
          question_count = Publication.published.size
          questions_answered = Post.answers.size
          followers = Relationship.select("DISTINCT follower_id").size 
          [question_count, questions_answered, followers]
        end
        @actions = Post.recent_activity_on_posts(posts, Publication.recent_responses(posts))

        render 'index'
      else # logged out user, new homepage
        render 'index_with_search'
      end
    end
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

  def unauth_show
    show true
  end

  def show force = false
    if !current_user and params[:q] == "1" and params[:id]
      redirect_to user_omniauth_authorize_path(:twitter, :feed_id => params[:id], :q => 1, :use_authorize => false)
    elsif current_user.nil? and force == false
      redirect_to request.fullpath.gsub(/^\/u/, ""), params
      # redirect_to "/u#{request.fullpath}", params
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

        if current_user and Post.create_split_test(current_user.id, 'other feeds panel shows related askers (=> regular)', 'false', 'true') == 'true'
          subscribed = current_user.asker_follows.includes(:related_askers)
          @related = subscribed.collect {|a| a.related_askers }.flatten.uniq.reject {|a| subscribed.include? a }.sample(3)
        else
          @related = Asker.select([:id, :twi_name, :description, :twi_profile_img_url])\
            .where(:id => ACCOUNT_DATA.keys.sample(3)).all
        end

        # contributors = User.find(@asker.questions.approved.ugc.collect { |q| q.user_id }.uniq.sample(3))
        # contributor_ids_with_count = @asker.questions.approved.ugc.group("user_id").count
        # contributors += [current_user] if current_user.questions.approved.ugc.where("created_for_asker_id = ?", @asker.id).present? and !contributors.include? current_user
        # @contributors = []
        # contributors.sample(3).each { |user| @contributors << {twi_screen_name: user.twi_screen_name, twi_profile_img_url: user.twi_profile_img_url, count: contributor_ids_with_count[user.id]}}

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

  def stream(user_followers = [])
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

  def scores
    @scores = User.get_top_scorers(params[:id])
  end

  def respond_to_question
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

    render :partial => "conversation"
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
      response_post = asker.private_response user_post, correct, 
        tell: tell,
        message: params[:message],
        username: params[:username],
        in_reply_to_user_id: params[:in_reply_to_user_id],
        conversation: conversation
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

    if params[:message].present?
      accepted_moderation_type_id = 6
    elsif tell == true
      accepted_moderation_type_id = 3
    elsif correct == true
      accepted_moderation_type_id = 1
    elsif correct == false
      accepted_moderation_type_id = 2
    end
        
    user_post.moderations.each do |moderation|
      if accepted_moderation_type_id == moderation.type_id
        moderation.update_attribute :accepted, true
        next if moderation.moderator.moderations.count > 1
        Post.trigger_split_test(moderation.user_id, "show moderator q & a or answer (-> accepted grade)")
      else
        moderation.update_attribute :accepted, false
      end
    end

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

  def manage
    @linked_box_count = Post.linked_box.count
    @unlinked_box_count = Post.unlinked_box.count
    @autocorrected_box_count = Post.autocorrected_box.count
    @moderated_box_count = Post.moderated_box.to_a.count
    @email_count = Post.requires_action.where(in_reply_to_post_id: Post.where("user_id in (?) and text like ?", Asker.ids, '%your email address%').collect(&:id)).count

    #filters
    @posts = Post.includes(:tags, :user, :parent, [:conversation => [:publication => [:question => :answers], :post => [:user], :posts => [:user]]])
    # @posts = Post.includes(:tags, :conversation)
    if params[:filter] == 'retweets'
      @posts = @posts.retweet_box.not_spam.order("posts.created_at DESC")
    elsif params[:filter] == 'spam'
      @posts = @posts.spam_box.order("posts.created_at DESC")
    elsif params[:filter] == 'autocorrected'
      @posts = @posts.autocorrected_box.not_spam.order("posts.created_at ASC")
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
    elsif params[:filter] == 'email'
      @posts = @posts.requires_action.where(in_reply_to_post_id: Post.where("user_id in (?) and text like ?", Asker.ids, '%your email address%').collect(&:id))   
    elsif params[:filter] == 'all'
      @posts = @posts.all_box.not_spam.order("posts.created_at DESC")
    else
      @posts = @posts.moderated_box.order("posts.created_at DESC")
    end

    @tags = Tag.all
    @asker_twi_screen_names = Asker.askers_with_id_and_twi_screen_name.sort_by! { |a| a.twi_screen_name.downcase }.each { |a| a.twi_screen_name = a.twi_screen_name.downcase }
    @nudge_types = NudgeType.all
    @posts = @posts.page(params[:page]).per(25)

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
