class AskersController < ApplicationController
  before_filter :admin?
  
  def index
    @askers = User.askers
    @new_posts = {}
    @submitted_questions = {}
    @askers.each do |a|
      unresponded = a.engagements.where(:responded_to => false).count
      @new_posts[a.id] = unresponded
      submitted = Question.where(:created_for_asker_id => a.id, :status => 0).count
      @submitted_questions[a.id] = submitted
    end
  end

  def show
    @asker = User.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'
    @posts = @asker.engagements.where(:responded_to => false).order('created_at DESC')
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

  def stats
    @headsup_stats = Stat.get_all_headsup
    @rts = Stat.get_all_retweets(30)
    @qa = Stat.get_all_questions_answered(30)
    @dau = Stat.get_all_dau(30)
    #@retention = {"2012-07-28"=>{"counts"=>[13, 0], "first"=>33}, "2012-07-29"=>{"counts"=>[36, 6], "first"=>76}, "2012-07-20"=>{"counts"=>[44, 7], "first"=>99}, "2012-07-21"=>{"counts"=>[37, 10], "first"=>101}, "2012-07-22"=>{"counts"=>[38, 5], "first"=>120}, "2012-07-23"=>{"counts"=>[40, 7], "first"=>121}, "2012-07-24"=>{"counts"=>[33, 6], "first"=>84}, "2012-07-25"=>{"counts"=>[34, 7], "first"=>75}, "2012-07-26"=>{"counts"=>[47, 3], "first"=>84}, "2012-07-27"=>{"counts"=>[30, 3], "first"=>67}, "2012-07-15"=>{"counts"=>[0, 0], "first"=>0}, "2012-07-17"=>{"counts"=>[53, 10], "first"=>135}, "2012-07-16"=>{"counts"=>[25, 7], "first"=>58}, "2012-07-30"=>{"counts"=>[40, 4], "first"=>79}, "2012-07-19"=>{"counts"=>[55, 8], "first"=>124}, "2012-07-18"=>{"counts"=>[47, 11], "first"=>138}} 
    @weekly_int_ret = Stat.internal_retention(70, 'week')
    @daily_int_ret = Stat.internal_retention(10, 'day')
    @weekly_twi_ret = Stat.twitter_retention(70)
    @daily_twi_ret = Stat.twitter_retention(10)
  end

  def account_rts
    @asker = User.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'

    @rts = @asker.twitter.retweets_of_me({:count => 100})
    #raise @rts.first.to_yaml
    @rts.each do |r|
      puts r.text
      #puts r.screen_name
      puts r.user.screen_name
    end
  end

  def dashboard
    @askers = User.askers
    @graph_data = Stat.get_month_graph_data(@askers)
    @display_data = Stat.get_display_data(@askers)

    @paulgraham, pg_display_data = Stat.paulgraham
    @display_data[0][:paulgraham] = pg_display_data
    @dau_mau, dau_mau_display_data = Stat.dau_mau
    @display_data[0][:dau_mau] = dau_mau_display_data
  end

  def report
    
  end  
end
