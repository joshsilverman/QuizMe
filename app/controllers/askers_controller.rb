class AskersController < ApplicationController
  before_filter :admin?
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
    @askers = @askers.sort{|a,b| @unresponded_counts[a.id] <=> @unresponded_counts[b.id]}.reverse
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

  def get_core_by_handle
    @askers = User.askers
    @core_display_data = {0 => {}}

    params.delete 'asker_id' if params[:asker_id] == '-1'

    @dau_mau, dau_mau_display_data = Stat.dau_mau params[:asker_id]
    @core_display_data[0][:dau_mau] = dau_mau_display_data

    @econ_engine, econ_engine_display_data = Stat.econ_engine params[:asker_id]
    @core_display_data[0][:econ_engine] = econ_engine_display_data 

    @paulgraham, pg_display_data = Stat.paulgraham params[:asker_id]
    @core_display_data[0][:paulgraham] = pg_display_data

    @revenue, revenue_display_data = Stat.revenue
    @core_display_data[0][:revenue] = revenue_display_data

    render :json => {
      :paulgraham => @paulgraham, 
      :dau_mau => @dau_mau, 
      :daus => @daus, 
      :revenue => @revenue, 
      :econ_engine => @econ_engine,
      :core_display_data => @core_display_data
    }
  end

  def graph

    #user
    if params[:graph] == 'cohort'
      @cohort = Stat.cohort_analysis
    elsif params[:graph] == 'ugc'
      @ugc_data = Stat.ugc
    elsif params[:graph] == 'questions_answered'
      @questions_answered_data = Stat.questions
    elsif params[:graph] == 'learner_levels'
      @learner_levels_data = Stat.learner_levels
    elsif params[:graph] == 'answer_source'
      @answer_source_data = Stat.answer_source
    elsif params[:graph] == 'lifecycle'
      @lifecycle_data = Stat.lifecycle
    elsif params[:graph] == 'age_v_reengagement_v_response_rate'
      @age_v_reengagement_v_response_rate_data = Stat.age_v_reengagement_v_response_rate
    elsif params[:graph] == 'days_since_active_when_reengaged_v_response_rate'
      @days_since_active_when_reengaged_v_response_rate_data = Stat.days_since_active_when_reengaged_v_response_rate
    elsif params[:graph] == 'days_since_active_v_number_of_reengagement_attempts'
      @days_since_active_v_number_of_reengagement_attempts_data = Stat.days_since_active_v_number_of_reengagement_attempts

    #asker graphs
    elsif params[:graph] == 'handle_activity'
      @handle_activity = Stat.handle_activity
    end
    render :partial => params[:party]
  end
end
