class BadgesController < ApplicationController
  before_filter :authenticate_user
  before_filter :admin?

  def index
    @badges = Badge.all
    @badges_by_asker = @badges.group_by{|b| b.asker_id}

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @badges }
    end
  end

  def show
    @badge = Badge.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @badge }
    end
  end

  def new
    @badge = Badge.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @badge }
    end
  end

  def edit
    @badge = Badge.find(params[:id])
  end

  def create
    @badge = Badge.new(params[:badge])

    respond_to do |format|
      if @badge.save
        format.html { redirect_to @badge, notice: 'Badge was successfully created.' }
        format.json { render json: @badge, status: :created, location: @badge }
      else
        format.html { render action: "new" }
        format.json { render json: @badge.errors, status: :unprocessable_entity }
      end
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

  def destroy
    @badge = Badge.find(params[:id])
    @badge.destroy

    respond_to do |format|
      format.html { redirect_to badges_url }
      format.json { head :ok }
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
