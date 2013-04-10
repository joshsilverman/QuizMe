class AskersController < ApplicationController
  before_filter :admin?, :except => [:tutor, :dashboard, :get_core_metrics, :graph]
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

  def get_core_metrics
    @askers = User.askers
    @core_display_data = {0 => {}}
    @domain = params[:domain] || 30
    @domain = @domain.to_i

    params.delete 'asker_id' if params[:asker_id] == '-1'

    @dau_mau, dau_mau_display_data = Stat.dau_mau @domain
    @core_display_data[0][:dau_mau] = dau_mau_display_data

    @econ_engine, econ_engine_display_data = Stat.econ_engine @domain
    @core_display_data[0][:econ_engine] = econ_engine_display_data 

    @paulgraham, pg_display_data = Stat.paulgraham @domain
    @core_display_data[0][:paulgraham] = pg_display_data

    @revenue, revenue_display_data = Stat.revenue @domain
    @core_display_data[0][:revenue] = revenue_display_data

    render :json => {
      :paulgraham => @paulgraham, 
      :dau_mau => @dau_mau, 
      :daus => @daus, 
      :revenue => @revenue, 
      :econ_engine => @econ_engine,
      :core_display_data => @core_display_data
    }, :locals => {domain: @domain}
  end

  def graph
    @domain = params[:domain] || 30
    @domain = @domain.to_i

    begin
      name = "graph_#{params[:graph]}"
      @data = Stat.send name, @domain
    rescue
    end
    
    render :partial => params[:party]
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

  def graph 
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
end
