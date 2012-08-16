class AskersController < ApplicationController
  before_filter :admin?
  
  def index
    @askers = User.askers
  end

  def show
    @asker = User.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'
    @engagements = Engagement.where("provider = 'twitter' and created_at > ? and asker_id = ?", Time.now - 7.days, @asker.id).order('created_at DESC')
  end

  def new
    @asker = User.new
  end

  def edit
    @asker = User.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'
  end

  def create
    @asker = User.new()
    @asker.role = 'asker'
    @asker.posts_per_day = params[:posts_per_day]
    @asker.name = params[:name]
    @asker.description = params[:description]

    respond_to do |format|
      if @asker.save
        format.html { redirect_to "/askers/#{@asker.id}/edit", notice: 'Account was successfully created.' }
        format.json { render json: @asker, status: :created, location: @asker }
      else
        format.html { render action: "new" }
        format.json { render json: @asker.errors, status: :unprocessable_entity }
      end
    end
  end


  def update
  	@asker = User.find(params[:id])
    redirect_to root_url unless @asker.is_role? 'asker'

    if @asker.update_attributes(params[:asker])
      redirect_to @asker, notice: 'Asker account was successfully updated.'
    else
      render action: "edit"
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
end
