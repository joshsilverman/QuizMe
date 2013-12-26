class BadgesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :admin?

  def index
    @badges = Badge.all
    @badges_by_asker = @badges.group_by{|b| b.asker_id}
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