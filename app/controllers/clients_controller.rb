class ClientsController < ApplicationController
  before_filter :client?
  before_filter :admin?, :except => :report
  
  def report

    @client = Client.find params[:id]
    redirect_to "/" unless @client
    @askers = @client.askers
    @rate_sheet = @client.rate_sheet
    unless @rate_sheet 
      @rate_sheet = RateSheet.create
      @rate_sheet.clients << @client
    end

    @posts = Post.not_spam.includes(:user)\
        .where("in_reply_to_user_id IN (?) AND users.role != 'asker'", @askers.collect(&:id))\
        .select([:text, "posts.created_at", :in_reply_to_user_id, :twi_screen_name, :interaction_type, :correct, :user_id, :spam, :autospam, "users.role", "users.twi_screen_name"])\
        .order("posts.created_at DESC")
    @posts_by_week = @posts.group_by{|p| p.created_at.strftime('%W')}
    @posts_by_month = @posts.group_by{|p| p.created_at.strftime('%m')}

    @posts_by_week_by_it = {}
    @posts_by_month_by_it = {}

    @posts_by_week_by_user = {}
    @posts_by_month_by_user = {}

    @posts_by_week.each{|w,posts| @posts_by_week_by_it[w] = posts.group_by{|p| p.interaction_type}}
    @posts_by_month.each{|m,posts| @posts_by_month_by_it[m] = posts.group_by{|p| p.interaction_type}}

    @posts_by_week.each{|w,posts| @posts_by_week_by_user[w] = posts.group_by{|p| p.user_id}}
    @posts_by_month.each{|m,posts| @posts_by_month_by_user[m] = posts.group_by{|p| p.user_id}}

    #graph data
    @waus = []
    asker_ids = @posts.group_by{|p| p.in_reply_to_user_id}.keys
    @posts_by_week.each do |w,posts| 
      row = [@posts_by_week[w].first.created_at.beginning_of_week.strftime("%m/%d")] + [].fill(0, 0, asker_ids.count)
      posts.group_by{|p| p.in_reply_to_user_id}.each do |asker_id, pposts|
        next unless asker_ids.index asker_id
        row[asker_ids.index(asker_id) + 1] = pposts.group_by{|p| p.user_id}.count
      end
      @waus << row
    end
    @waus.sort!{|a,b| a[0] <=> b[0]}
    @waus = [["Date"] + asker_ids.map{|asker_id| Asker.find(asker_id).twi_screen_name}] + @waus
    @waus.pop

    @correct_count_by_user = Post.not_spam\
      .where("in_reply_to_user_id IN (?)", @askers.collect(&:id))\
      .where('correct = ?', true)\
      .group(:user_id).count
    @incorrect_count_by_user = Post.not_spam\
      .where("in_reply_to_user_id IN (?)", @askers.collect(&:id))\
      .where('correct = ?', false)\
      .group(:user_id).count
    @other_posts_count_by_user = Post.not_spam\
      .where("in_reply_to_user_id IN (?)", @askers.collect(&:id))\
      .where('correct IS NULL')\
      .group(:user_id).count
  end

  def nudge
    @user = User.find params[:user_id]
    @asker = Asker.find params[:asker_id]
    unless @asker and @user
      render :text => 'no user or no asker', :status => 404
      return
    end

    if @user.client_nudge
      render :text => 'user already nudged', :status => 400
      return
    end

    @user.client_nudge = true
    message = "You're doing really well! I offer a much more comprehensive (free) course here:"
    long_url = "http://www.testive.com/sathabit/?version=email&utm_source=wisr&utm_twi_screen_name=#{@user.twi_screen_name}"
    dm_status = Post.dm(@asker, @user, message, {:long_url => long_url, :link_type => 'wisr', :include_url => true})
    puts "dm status: #{dm_status}" 
    @user.save

    render :text => nil, :status => 200
  end
end
