class BadgesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :admin?

  def index
    @badges = Badge.all
    @badges_by_asker = @badges.group_by{|b| b.asker_id}

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @badges }
    end
  end

  def issuable
    @posts = Post.not_spam.joins(:user)\
      .includes(:user => :badges, :parent => {:user => {}, :publication => {:question => :badges}})\
      .where("correct IS NOT NULL")\
      .order('posts.created_at DESC')\
      .page(params[:page]).per(25)

    @users_with_posts = []
    user = nil
    @posts.each do |post|
      if user and user == post.user
        @users_with_posts[@users_with_posts.count - 1][1] << post
      else
        user = post.user
        @users_with_posts << [user, [post]]
      end
    end
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
        Post.tweet(@badge.asker, tweet, :long_url => long_url)

        render :nothing => true, :status => 200
      end
    else
      render :nothing => true, :status => 400
    end
  end

  # def show
  #   @badge = Badge.find(params[:id])

  #   respond_to do |format|
  #     format.html # show.html.erb
  #     format.json { render json: @badge }
  #   end
  # end

  # def new
  #   @badge = Badge.new

  #   respond_to do |format|
  #     format.html # new.html.erb
  #     format.json { render json: @badge }
  #   end
  # end

  # def edit
  #   @badge = Badge.find(params[:id])
  # end

  # def create
  #   @badge = Badge.new(params[:badge])

  #   respond_to do |format|
  #     if @badge.save
  #       format.html { redirect_to @badge, notice: 'Badge was successfully created.' }
  #       format.json { render json: @badge, status: :created, location: @badge }
  #     else
  #       format.html { render action: "new" }
  #       format.json { render json: @badge.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

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

  # def destroy
  #   @badge = Badge.find(params[:id])
  #   @badge.destroy

  #   respond_to do |format|
  #     format.html { redirect_to badges_url }
  #     format.json { head :ok }
  #   end
  # end

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
