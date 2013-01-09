class UsersController < ApplicationController
  before_filter :admin?, :except => [:show, :badges]

  def show
    @user = User.where("twi_screen_name ILIKE '%#{params[:twi_screen_name]}%'").first
    if @user.nil?
      redirect_to "/"
    elsif @user.is_role? "asker"
      redirect_to "/feeds/#{@user.id}"
    else
      redirect_to "/#{params[:twi_screen_name]}/badges"
    end
  end

  def badges
    @user = User.where("twi_screen_name ILIKE ?", params[:twi_screen_name]).first
    if @user.nil?
      redirect_to "/"
    elsif @user.is_role? "asker"
      redirect_to "/feeds/#{@user.id}"
    end

    @badges = Badge.all
    @badges_by_asker = @badges.group_by{|b| b.asker_id}
    @user_badges = @user.badges
    @user_badges_ids = @user.badges.collect &:id

    @is_story = !%r/\/story\//.match(request.fullpath).nil?

    @badge_for_modal_id = nil
    @badge_for_modal = nil

    if params[:badge_title]
      @badge_for_modal = Badge.where("title ILIKE ?", params[:badge_title].titleize).first
      @badge_for_modal_id = @badge_for_modal.id unless @badge_for_modal.blank?

      puts params[:badge_title]
      puts @badge_for_modal
      puts @user_badges.include? @badge_for_modal

      if @badge_for_modal.blank? or !@user_badges.include? @badge_for_modal
        redirect_to "/#{params[:twi_screen_name]}/badges"
      end
    end
  end

  def update
    @user = User.find(params[:id])

    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to @user, notice: 'User was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end
end