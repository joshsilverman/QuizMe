class AskersController < ApplicationController
  before_filter :admin?, :except => [:tutor, :dashboard, :get_core_metrics, :graph, :questions]
  before_filter :yc_admin?, :only => [:dashboard, :get_core_metrics, :graph]

  caches_action :get_core_by_handle, :expires_in => 7.minutes
  caches_action :get_handle_metrics, :expires_in => 11.minutes

  def index
    @new_posts = {}
    @submitted_questions = {}
    asker_ids = Asker.ids
    
    @unresponded_counts = Asker.unresponded_counts
    @unmoderated_counts = Question.unmoderated_counts
    @ugc_post_counts = Post.ugc_post_counts
    @question_counts = Question.counts
    
    @askers = Asker.all
    @askers = @askers.sort{|a,b| (@unresponded_counts[a.id] or 0) <=> (@unresponded_counts[b.id] or 0)}.reverse
    @askers = @askers.reject{|a| !a.published} + @askers.reject{|a| a.published}
  end

  def show
    @asker = Asker.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'
    @posts = @asker.engagements.where(:requires_action => true).order('created_at DESC')
  end

  def edit
    @asker = Asker.find(params[:id])
    @linked = true

    if @asker.twi_user_id.nil?
      @linked = false
      @asker.twi_profile_img_url = 'unknown_user.jpeg'
      @asker.twi_screen_name = 'unlinked'
      @asker.twi_user_id = "unknown id"
    end

    redirect_to root_url unless @asker.is_role? 'asker'
  end

  def update
  	@asker = Asker.find(params[:id])
    redirect_to root_url if @asker.nil?

    #update twitter - designed for use with best_in_place - hence the individual field updates
    if (params[:asker][:description])
      profile = {:description => params[:asker][:description]}
      @asker.twitter.update_profile profile
    end
    
    if params[:asker][:published] == "true"
      PublicationQueue.enqueue_questions @asker
    end

    if @asker.update_attributes(params[:asker])
      render :status => 200, :text => ''
    else
      render :status => 400, :text => ''
    end
  end

  def destroy
    @asker = Asker.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'
    @asker.destroy

		redirect_to askers_url
  end

  def hide_all
    ids = params[:post_ids].split "+"
    @posts = Post.where("id IN (?)", ids)
    @posts.each{|post| post.update_attribute :requires_action, false}
    redirect_to "/feeds/#{params[:id]}/manage"
  end

  def account_rts
    @asker = Asker.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'

    @rts = @asker.twitter.retweets_of_me({:count => 100})
    #raise @rts.first.to_yaml
  end

  def dashboard
    @askers = User.askers
  end 

  def graph
    @domain = params[:domain] || 30
    @domain = @domain.to_i

    begin
      name = "graph_#{params[:graph]}"
      @data = Stat.send name, @domain
    rescue
    end
    
    if params[:party] == 'core'
      render json: @data
    else
      render :partial => params[:party]
    end
  end

  def send_nudge
    asker = Asker.find(params[:asker_id])
    user = User.find(params[:user_id])
    nudge_type = NudgeType.find(params[:nudge_type_id])

    nudge_type.send_to(asker, user)

    render :nothing => true
  end

  def tutor
    # Query to create NudgeType in db:
    # NudgeType.create({:client_id => 29210, :url => "http://www.wisr.com/tutor?user_id={user_id}", :text => "We provide a tutoring service, check it out: {link}", :active => true, :automatic => false})
    @exams = User.find(params[:user_id]).exams
    @exam = @exams.last || Exam.new
  end

  def edit_graph
    @askers = {}
    Asker.includes(:related_askers).each do |asker|
      @askers[asker.id] ||= { twi_screen_name: asker.twi_screen_name }
      asker.related_askers.each do |related_asker|
        (@askers[asker.id][:related_asker_ids] ||= []) << related_asker.id
      end
    end
  end

  def add_related
    asker = Asker.find(params[:asker_id])
    related_asker = Asker.find(params[:related_asker_id])
    asker.related_askers << related_asker unless asker.related_askers.include? related_asker
    render :nothing => true
  end

  def remove_related
    Asker.find(params[:asker_id]).related_askers.delete Asker.find(params[:related_asker_id])
    render :nothing => true
  end

  def import
    @asker = Asker.find params[:id]
    @asker.seeder_import params[:seeder_id]
    redirect_to :back
  end

  def questions
    if !current_user
      redirect_to user_omniauth_authorize_path(:twitter, :use_authorize => false, :asker_id => params[:id]) unless current_user
    else
      @asker = Asker.find(params[:id])
      @questions = @asker.questions.includes(:answers, :user).order("questions.id DESC").page(params[:page]).per(15)
      @question_count = @asker.questions.group("status").count
      [-1, 0, 1].each { |status| @question_count[status] ||= 0 }
      
      if params[:user_id] and (users_questions = @questions.where(user_id: params[:user_id])).present?
        @questions = users_questions.order("status")
      end

      # if params[:question_id]
      #   @requested_question = @asker.questions.where(id: params[:question_id]).first
      #   @questions.reverse!.push(@requested_question).reverse! unless @requested_question.blank? or @questions.include?(@requested_question)
      # end

      @contributors = []
      contributors = User.find(@asker.questions.approved.collect { |q| q.user_id }.uniq)
      contributor_ids_with_count = @asker.questions.approved.group("user_id").count
      contributors.shuffle.each do |user|
        @contributors << {twi_screen_name: user.twi_screen_name, twi_profile_img_url: user.twi_profile_img_url, count: contributor_ids_with_count[user.id]}
      end      
    end
  end  
end
