class AskersController < ApplicationController
  before_filter :admin?
  
  def index
    @askers = User.askers.order "created_at ASC"
    @new_posts = {}
    @submitted_questions = {}
    asker_ids = User.askers.collect(&:id)
    askers_engagements = Post.where("requires_action = ? and in_reply_to_user_id in (?) and (spam = ? or spam is null) and user_id not in (?)", true, asker_ids, false, asker_ids).group_by(&:in_reply_to_user_id)
    # puts askers_engagements.to_json
    @askers.each do |a|
      unresponded = askers_engagements[a.id].try(:size) || 0
      # unresponded = a.engagements.where(:responded_to => false).count
      @new_posts[a.id] = unresponded
      submitted = Question.where(:created_for_asker_id => a.id, :status => 0).count
      @submitted_questions[a.id] = submitted
    end
  end

  def show
    @asker = User.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'
    @posts = @asker.engagements.where(:requires_action => true).order('created_at DESC')
  end

  def edit
    @asker = User.find(params[:id])
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
  	@asker = User.askers.find(params[:id])
    redirect_to root_url if @asker.nil?

    #update twitter - designed for use with best_in_place - hence the individual field updates
    if (params[:user][:description])
      profile = {:description => params[:user][:description]}
      @asker.twitter.update_profile profile
    end

    if @asker.update_attributes(params[:user])
      render :status => 200, :text => ''
    else
      render :status => 400, :text => ''
    end
  end

  def destroy
    @asker = User.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'
    @asker.destroy

		redirect_to askers_url
  end

  def account_rts
    @asker = User.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'

    @rts = @asker.twitter.retweets_of_me({:count => 100})
    #raise @rts.first.to_yaml
  end

  def dashboard
    @askers = User.askers
    @graph_data = Stat.get_month_graph_data(@askers)
    @display_data = Stat.get_display_data(@askers)

    @paulgraham, pg_display_data = Stat.paulgraham
    @display_data[0][:paulgraham] = pg_display_data

    @dau_mau, dau_mau_display_data = Stat.dau_mau
    @display_data[0][:dau_mau] = dau_mau_display_data

    @econ_engine, econ_engine_display_data = Stat.econ_engine
    @display_data[0][:econ_engine] = econ_engine_display_data
  end 
end
