class SessionsController < Devise::SessionsController

  def confirm_js
    if Rails.env.test?
      render :nothing => true
      return
    end

    ab_user.confirm_js(session[:user_agent], session[:remote_ip])
    render :nothing => true
  end

  def new
    # choose random asker for styling
    @asker = Asker.published.sample
    @asker.subject = 'Sign In'

    respond_to do |format|
      format.html.phone do
        render :new, layout: 'phone'
      end
      
      format.html.none {}
    end
  end
end
