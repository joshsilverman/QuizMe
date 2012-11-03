class UsersController < ApplicationController
  #before_filter :admin?

  def show
    @user = User.where("twi_screen_name ILIKE '%#{params[:twi_screen_name]}%'").first

    if @user.nil?
      redirect_to "/"
    elsif @user.is_role? "asker"
      redirect_to "/feeds/#{@user.id}"
    elsif @user.is_role? "admin"
      redirect_to "/askers"
    else
      redirect_to "/#{params[:twi_screen_name]}/badges"
    end
  end

  def badges
    @badges = Badge.all
    @badges_by_asker = @badges.group_by{|b| b.asker_id}
  end
end