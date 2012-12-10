class AskersController < ApplicationController
  before_filter :admin?
  caches_action :get_core_by_handle, :expires_in => 7.minutes
  caches_action :get_handle_metrics, :expires_in => 11.minutes
  
  def index
    @new_posts = {}
    @submitted_questions = {}
    asker_ids = Asker.all.collect(&:id)
    
    @askers = Asker.all
    @askers.each do |a|
      @new_posts[a.id] = a.unresponded_count
      submitted = Question.where(:created_for_asker_id => a.id, :status => 0).count
      @submitted_questions[a.id] = submitted
    end
    @askers = @askers.sort{|a,b| @new_posts[a.id] <=> @new_posts[b.id]}.reverse
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

    @daus, daus_display_data = Stat.daus params[:asker_id]
    @core_display_data[0][:daus] = daus_display_data

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

  def get_handle_metrics
    @handle_activity = Stat.handle_activity
    @cohort = Stat.cohort_analysis
    @question_data = Stat.questions
    render :partial => "handles"
  end
end
