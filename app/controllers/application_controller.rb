class ApplicationController < ActionController::Base
  protect_from_forgery
  helper_method :current_user
  before_filter :referrer_data
  before_filter :split_user

  def authenticate_user
    redirect_to '/' unless current_user 
  end

  def admin?
    if current_user
      redirect_to '/' unless current_user.is_role? "admin"
    else
      redirect_to '/'
    end
  end

  def client?
    if current_user
      redirect_to '/' unless current_user.is_role? "client" or current_user.is_role? "admin"
    else
      redirect_to '/'
    end
  end

  private
  
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def split_user
    if (request.user_agent =~ /\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i)
      ab_user.set_id(0)
    elsif current_user
      puts "current_user"
      if session[:split]
        puts "in current_user session split"
        keys = Split.redis.hkeys("user_store:#{session[:split]}")
        keys.each do |key|
          if value = Split.redis.hget("user_store:#{session[:split]}", key)
            Split.redis.hset("user_store:#{current_user.id}", key, value)
          end
        end
        Split.redis.del("user_store:#{session[:split]}")
      end
      ab_user.set_id(current_user.id)
    elsif (session[:split])
      puts "in session split"
      ab_user.set_id(session[:split])
    else
      session[:split] = rand(10 ** 10).to_i
      ab_user.set_id(session[:split])
    end
    puts "id:"
    puts ab_user.identifier
  end

  def referrer_data
    @campaign = params[:c]
    @source = params[:s]
    @link_type = params[:lt]
  end
end
