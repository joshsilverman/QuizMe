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
    #temporary fix until devise
    # return unless cookies.signed[:permanent_user_id] || session[:user_id]
    # @current_user ||= User.find(cookies.signed[:permanent_user_id] || session[:user_id])
  end

  def split_user
    session[:user_agent] = request.user_agent
    session[:ip] = request.remote_ip
    puts "ApplicationController session save"
    puts session[:user_agent]
    puts session[:ip]
    if current_user
      if session[:split] and session[:split] != current_user.id
        keys = Split.redis.hkeys("user_store:#{session[:split]}")
        keys.each do |key|
          if value = Split.redis.hget("user_store:#{session[:split]}", key)
            Split.redis.hset("user_store:#{current_user.id}", key, value)
          end
        end
        confirmjs = Split.redis.get("user_store:#{session[:split]}:confirmed")
        Split.redis.set("user_store:#{current_user.id}:confirmed", confirmjs) unless confirmjs.nil?
        Split.redis.del("user_store:#{session[:split]}")
        Split.redis.del("user_store:#{session[:split]}:confirmed")
      end
      session[:split] = current_user.id
      ab_user.set_id(current_user.id)
    elsif (session[:split])
      ab_user.set_id(session[:split])
    else
      session[:split] = rand(10 ** 10).to_i
      ab_user.set_id(session[:split])
    end
  end

  def referrer_data
    @campaign = params[:c]
    @source = params[:s]
    @link_type = params[:lt]
  end
end
