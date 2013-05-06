class UsersController < ApplicationController
  before_filter :admin?, :except => [:show, :badges, :questions]

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

  def questions
    if !current_user
      redirect_to user_omniauth_authorize_path(:twitter, :use_authorize => false, :user_id => params[:id], :asker_id => params[:asker_id]) unless current_user
    else
      @user = User.find(params[:id])
      # redirect_to '/' unless current_user == @user
      
      @asker = Asker.find(params[:asker_id])
      @questions = @user.questions.where(:created_for_asker_id => params[:asker_id])

      @all_questions = @questions.includes(:answers, :publications, :asker).order("questions.id DESC")
      @questions_enqueued = @questions.includes(:answers, :publications, :asker).joins(:publications, :asker).where("publications.publication_queue_id IS NOT NULL").order("questions.id ASC")
      @questions = @questions.includes(:answers, :publications, :asker).where("publications.publication_queue_id IS NULL").order("questions.id DESC").page(params[:page]).per(25)

      @questions_hash = Hash[@all_questions.collect{|q| [q.id, q]}]
      @handle_data = User.askers.collect{|h| [h.twi_screen_name, h.id]}
      @approved_count = @all_questions.where(:status => 1).count
      @pending_count = @all_questions.where(:status => 0).count

      @questions_answered_count = Post.answers\
        .where("in_reply_to_question_id in (?)", @questions.collect(&:id))\
        .group("posts.in_reply_to_question_id")\
        .count
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
end