class BadgesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :admin?

  def index
    @badges = Badge.all
    @badges_by_asker = @badges.group_by{|b| b.asker_id}
  end

  def issue
    @user = User.find params[:user_id]
    @badge = Badge.find params[:badge_id]
    if @user and @badge
      if @user.badges.include? @badge
        render :nothing => true, :status => 304
      else  
        @user.badges << @badge

        #tweet = params[:tweet].gsub('\n', '').strip
        # @bug the shortening script is removing way too much
        tweet = "@#{@user.twi_screen_name} You earned the #{@badge.title} badge"
        
        long_url = "#{URL}/#{@user.twi_screen_name}/badges/story/#{@badge.title.parameterize}"
        @badge.asker.send_public_message(tweet, :long_url => long_url)

        render :nothing => true, :status => 200
      end
    else
      render :nothing => true, :status => 400
    end
  end

  def update
    @badge = Badge.find(params[:id])

    respond_to do |format|
      if @badge.update_attributes(params[:badge])
        format.html { redirect_to @badge, notice: 'Badge was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @badge.errors, status: :unprocessable_entity }
      end
    end
  end

  def load
    path = "#{Rails.root}/app/assets/images/badges"
    Dir.foreach(path) do |dir_name|
      next if dir_name == '.' or dir_name == '..'
      Dir.foreach("#{path}/#{dir_name}") do |fname|
        next if fname == '.' or fname == '..'
        next if !fname.match("-nocolor.").nil?
        
        @asker = User.where("twi_screen_name ILIKE ?", dir_name).first
        next unless @asker
        @badge = Badge.find_or_create_by_filename fname
        @badge.asker_id = @asker.id
        @badge.save
      end
    end

    redirect_to "/badges"
  end
end