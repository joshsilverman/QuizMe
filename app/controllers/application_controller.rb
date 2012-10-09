class ApplicationController < ActionController::Base
  protect_from_forgery
  helper_method :current_user
  before_filter :referrer_data

  before_filter :set_abingo_identity

  def authenticate_user
    redirect_to '/' unless current_user 
  end

  def admin?
    if current_user
      redirect_to '/' unless current_user and current_user.is_role? "admin"
    else
      redirect_to '/'
    end
  end

  private
  
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def referrer_data
    @campaign = params[:c]
    @source = params[:s]
    @link_type = params[:lt]
  end

  def set_abingo_identity
    #Abingo.identity = session[:abingo_identity]# = rand(10 ** 10).to_i
    #session[:abingo_identity] = Abingo.identity = rand(10 ** 10).to_i
    #return
    #Abingo.identity = session[:abingo_identity]
    if (request.user_agent =~ /\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i)
      Abingo.identity = "robot"
    elsif current_user
      Abingo.identity = current_user.id
    elsif (session[:abingo_identity])
      Abingo.identity = session[:abingo_identity]
    else
      session[:abingo_identity] = Abingo.identity = rand(10 ** 10).to_i
    end
    Abingo.options[:expires_in] = 1.hour
  end
end
