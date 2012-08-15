class AccountsController < ApplicationController
  before_filter :admin?
  
  def index
    @accounts = Account.all
  end

  def show
    @account = Account.find(params[:id])
    @engagements = @account.engagements.where("provider = 'twitter' and created_at > ?", Time.now - 7.days).order('created_at DESC')
    session[:account_id] = params[:id]
  end

  def new
    @account = Account.new
  end

  def edit
    @account = Account.find(params[:id])
    session[:account_id] = params[:id]
  end

  def create
    @account = Account.new(params[:account])

    respond_to do |format|
      if @account.save
        format.html { redirect_to @account, notice: 'Account was successfully created.' }
        format.json { render json: @account, status: :created, location: @account }
      else
        format.html { render action: "new" }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  def update_omniauth
    return if current_acct.nil?
    auth = request.env['omniauth.auth']
    provider = auth['provider']

    case provider
    when 'twitter'
      current_acct.update_attributes(:twi_oauth_token => auth['credentials']['token'],
                                    :twi_oauth_secret => auth['credentials']['secret'],
                                    :twi_name => auth['info']['name'],
                                    :twi_screen_name => auth['info']['nickname'],
                                    :twi_user_id => auth['uid'].to_i,
                                    :twi_profile_img_url => auth['info']['image'])
    when 'tumblr'
      current_acct.update_attributes(:tum_oauth_token => auth['credentials']['token'],
                                    :tum_oauth_secret => auth['credentials']['secret'])
    when 'facebook'
      current_acct.update_attributes(:fb_oauth_token => auth['credentials']['token'],
                                    :fb_oauth_secret => auth['credentials']['secret'])
    else
      puts "provider unknown: #{provider}"
    end
    redirect_to "/accounts/#{current_acct.id}"
  end

  def update
  	@account = Account.find(params[:id])

    if @account.update_attributes(params[:account])
      redirect_to @account, notice: 'Account was successfully updated.'
    else
      render action: "edit"
    end
  end


  def destroy
    @account = Account.find(params[:id])
    @account.destroy

		redirect_to accounts_url
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
    @account = Account.find(params[:id])

    @rts = @account.twitter.retweets_of_me({:count => 100})
    #raise @rts.first.to_yaml
    @rts.each do |r|
      puts r.text
      #puts r.screen_name
      puts r.user.screen_name
    end
  end
end
