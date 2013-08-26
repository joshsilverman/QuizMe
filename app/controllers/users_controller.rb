class UsersController < ApplicationController
  before_filter :admin?, :except => [:show, :badges, :questions, :unsubscribe, :unsubscribe_form, :asker_questions, :activity, :activity_feed, :add_email]

  def supporters
    @supporters = User.supporters
  end

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

  def activity_feed
    @activity = current_user.activity(since: 1.month.ago)
    render :partial => 'activity_feed'  
  end

  def activity
    @user = User.find(params[:id])
    @activity = @user.activity(since: 1.month.ago)
    @subscribed = Asker.includes(:related_askers).where("id in (?)", @user.follows.collect(&:id))
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

  def add_email
    if status = current_user.update(email: params[:email])
      Post.trigger_split_test(current_user.id, 'request email after answer script (provides email address)')
    end
    
    render :json => status
  end

  def create_supporter
    User.create role: 'supporter', name: params['user']['name'], email: params['user']['email']
    redirect_to '/users/supporters'
  end

  def destroy_supporter
    User.where("role = 'supporter' and id = ?", params['id']).first.destroy
    redirect_to '/users/supporters'
  end

  def touch_supporter
    User.where("role = 'supporter' and id = ?", params['id']).first.touch
    redirect_to '/users/supporters'
  end

  def newsletter
    @user = User.find 11
    @jason_text = "We've been running an A/B test for the past couple of weeks that tests two options: A. we post a tweet on Twitter on behalf of the user whenever they answer a question on Wisr and B. we do not post a tweet, but post a congratulatory summary of their activity from our account at the end of their session. Our goal in comparing these options was to discover which resulted in more retweets/shares, which correlates with higher perceived value to the end-user and free viral growth for us. We've found that, with 95% certainty, option B is superior at getting a given user to retweet. In terms of absolute number of retweets generated via each option, B also comes out ahead at 146 retweet for the lifetime of the experiment versus just 66 for A."
    @josh_text = "Our monetization strategy moved forward this week with progress with both existing clients and groundwork for a new client. Despite this, I'm more excited about selling directly to our end-users. I don't know when we'll have time to test this but I hope it's soon!"


    # drive = GoogleDrive.login("jsilverman@studyegg.com", "GlJnb@n@n@")
    # spreadsheet = drive.spreadsheet_by_key("0AliLeS3-noSidGJESjZoZy11bHo2ekNQS2I5TGN6eWc").worksheet_by_title('Sheet1')
    # last_row_index = spreadsheet.num_rows - 2
    # list = spreadsheet.list

    # @jason_text = [list.get(last_row_index, 'Jason Serendipity'), list.get(last_row_index - 1, 'Jason Serendipity')].reject { |t| t.blank? }.first
    # @josh_text = [list.get(last_row_index, 'Josh Serendipity'), list.get(last_row_index - 1, 'Josh Serendipity')].reject { |t| t.blank? }.first
    @name = @user.name || @user.twi_name
    @weeks = (Date.today - Date.new(2012,8,20)).to_i/7

    render "user_mailer/newsletter", :layout => false
  end

  def unsubscribe_form
    @user = User.find(params[:id])
  end

  def unsubscribe
    user = User.find(params[:user_id])
    user.update_attribute :subscribed, false if user.email.downcase == params[:email].downcase
    render :json => user.subscribed
  end

  # def progress_report
  #   @user = User.find(20)
  #   @user = User.find_by_twi_screen_name('LarryCox6')
  #   @activity_summary = @user.activity_summary(since: 1.week.ago, include_ugc: true, include_progress: true, include_moderated: true)
  #   @asker_hash = Asker.published.group_by(&:id)
  #   @scripts = [
  #     "How can we make this service better?",
  #     "Any new topics that you'd like to learn about?",
  #     "What other information should we put into this progress report?",
  #     "Is this progress report helpful?"
  #   ]    
    
  #   render "user_mailer/progress_report", :layout => false
  # end
end