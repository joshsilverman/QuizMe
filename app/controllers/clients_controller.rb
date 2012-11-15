class ClientsController < ApplicationController
  before_filter :client?
  
  def report
    @client = Client.find params[:id]
    redirect_to "/" unless @client
    @askers = @client.askers
    @rate_sheet = @client.rate_sheet
    unless @rate_sheet 
      @rate_sheet = RateSheet.create
      @rate_sheet.clients << @client
    end

    @posts = Post.not_spam.joins(:user)\
        .where("in_reply_to_user_id IN (?) AND users.role != 'asker'", @askers.collect(&:id))\
        .select([:text, "posts.created_at", :in_reply_to_user_id, :twi_screen_name, :interaction_type, :correct, :user_id, :spam, :autospam, "users.role", "users.twi_screen_name"])\
        .order("posts.created_at DESC")
    @posts_by_week = @posts.group_by{|p| p.created_at.strftime('%W')}
    @posts_by_month = @posts.group_by{|p| p.created_at.strftime('%m')}
    #@posts_by_week.delete @posts_by_week.keys.max # ignore most recent week (incomplete)

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
    @posts_by_week.each do |w,posts| 
      @waus << [@posts_by_week[w].first.created_at.beginning_of_week.strftime("%m/%d"), posts.group_by{|p| p.user_id}.count]
    end
    @waus.sort!{|a,b| a[0] <=> b[0]}
    @waus = [["Date", "WAUs"]] + @waus
    @waus.pop
  end
end
