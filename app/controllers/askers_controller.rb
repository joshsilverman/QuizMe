class AskersController < ApplicationController
  prepend_before_filter :check_for_authentication_token, :only => [:questions]

  before_filter :admin?, :except => [:dashboard, :get_core_metrics, :graph, :questions, :index, :recent]
  before_filter :authenticate_user!, :only => [:recent]
  
  before_filter :yc_admin?, :only => [:dashboard, :get_core_metrics, :graph]

  caches_action :get_core_by_handle, :expires_in => 7.minutes
  caches_action :get_handle_metrics, :expires_in => 11.minutes

  def index
    @askers = Asker.order(:subject).to_a

    respond_to do |format|
      format.html { admin? } # will redirect if not admin
      format.json { render json: askers_to_json(@askers) }
    end
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

    if (params[:asker][:description])
      profile = {:description => params[:asker][:description]}
      @asker.twitter.update_profile profile
    end
    
    if params[:asker][:published] == "true"
      PublicationQueue.enqueue_questions @asker
    end

    if @asker.update_attributes(params[:asker])
      head :ok
    else
      head :bad_request
    end
  end

  def recent
    recent_asker_ids = current_user.posts.order(created_at: :desc)
      .limit(50).pluck(:in_reply_to_user_id).uniq[0..4]

    recent_askers = Asker.where(id: recent_asker_ids).order(:subject)

    respond_to do |format|
      format.json { render json: askers_to_json(recent_askers) }
    end
  end

  def dashboard
    @askers = User.askers
  end 

  def graph
    @domain = params[:domain] || 30
    @domain = @domain.to_i

    name = "graph_#{params[:graph]}"
    @data = Stat.send name, @domain
    
    if params[:party] == 'core'
      render json: @data
    else
      render :partial => params[:party]
    end
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

  def questions
    if !current_user
      redirect_to user_omniauth_authorize_path(:twitter, :use_authorize => false, :asker_id => params[:id]) unless current_user
    else
      @asker = Asker.find(params[:id])
      @questions = @asker.questions.includes(:answers, :user).order("questions.id DESC").page(params[:page]).per(15)
      @question_count = @asker.questions.group("status").count
      [-1, 0, 1].each { |status| @question_count[status] ||= 0 }
      
      @requested_user_id = nil
      if params[:user_id] and (users_questions = @questions.where(user_id: params[:user_id])).present?
        @requested_user_id = params[:user_id]
        @questions = users_questions.order("status")
      end

      @contributors = []
      contributors = User.find(@asker.questions.approved.collect { |q| q.user_id }.uniq)
      contributor_ids_with_count = @asker.questions.approved.group("user_id").count
      contributors.shuffle.each do |user|
        @contributors << {twi_screen_name: user.twi_screen_name, twi_profile_img_url: user.twi_profile_img_url, count: contributor_ids_with_count[user.id]}
      end      
    end
  end  

  private

  def askers_to_json askers
    asker_hashes = []
    askers.each do |asker|
      asker_hash = {}
      [:id,
        :twi_name, :twi_screen_name, :twi_profile_img_url,
        :subject, :subject_url,
        :description, 
        :bg_image,
        :published].each do |attribute|

        asker_hash[attribute] = asker.send attribute
      end
      asker_hashes << asker_hash
    end

    asker_hashes.to_json
  end
end