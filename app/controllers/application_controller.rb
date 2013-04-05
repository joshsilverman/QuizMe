class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :referrer_data
  before_filter :split_user
  before_filter :preload_models

  def unauthenticated_user!
    if current_user
      redirect_to request.fullpath.gsub(/^\/u/, ""), params
    end
  end

  def after_sign_in_path_for resource, redirect_to = nil
    omniauth_redirect_params = request.env["omniauth.params"]
    if omniauth_redirect_params
      if omniauth_redirect_params["feed_id"]
        if omniauth_redirect_params['feed_id'] == "1"
          redirect_to = "/feeds/index/#{omniauth_redirect_params['post_id']}/#{omniauth_redirect_params['answer_id']}"
        else
          if omniauth_redirect_params["q"] == "1"
            redirect_to = "/feeds/#{omniauth_redirect_params['feed_id']}?q=1"
          else
            redirect_to = "/feeds/#{omniauth_redirect_params['feed_id']}/#{omniauth_redirect_params['post_id']}/#{omniauth_redirect_params['answer_id']}"
          end
        end      
      else
        redirect_to = request.env['omniauth.origin']
      end
    else
      redirect_to = root_path
    end

    redirect_to
  end  

  def after_sign_out_path_for resource, redirect_to = nil
    request.referer || root_path
  end    

  # preload models so caching works in development
  # http://aaronvb.com/articles/37-rails-caching-and-undefined-class-module
  def preload_models
    if Rails.env == "development"
      Dir.foreach("#{Rails.root}/app/models") do |model_name|
        require_dependency model_name unless model_name == "." || model_name == ".." || model_name == ".gitkeep"
      end 
    end
  end

  def admin?
    if current_user
      redirect_to '/' unless current_user.is_role? "admin"
    else
      redirect_to '/'
    end
  end

  def yc_admin?
    if current_user
      redirect_to '/' unless current_user.is_role? "admin"
    else
      redirect_to '/' unless params['yc'] == 'c43fd33b93c52207b118ce0150c55b3c'
    end
  end

  def client?
    if current_user
      redirect_to '/' unless current_user.is_role? "client" or current_user.is_role? "admin"
    else
      redirect_to '/'
    end
  end

  def author?
    if current_user
      redirect_to '/' unless current_user.is_role? "author" or current_user.is_role? "admin"
    else
      redirect_to '/'
    end
  end

  def set_session_variables
    if params["lt"] == "reengage" and params[:post_id].present?
      session[:reengagement_publication_id] = params[:post_id] 
      session[:referring_user] = params["t"]
    end
  end

  private
  
  # def current_user
    # @current_user ||= User.find(session[:user_id]) if session[:user_id]
    #temporary fix until devise
    # return unless cookies.signed[:permanent_user_id] || session[:user_id]
    # @current_user ||= User.find(cookies.signed[:permanent_user_id] || session[:user_id])
  # end

    def split_user
      session[:user_agent] = request.user_agent
      session[:ip] = request.remote_ip
      if current_user
        if session[:split] and session[:split] != current_user.id
          user_keys = Split.redis.hkeys("user_store:#{current_user.id}")
          if user_keys.blank?
            keys = Split.redis.hkeys("user_store:#{session[:split]}")
            keys.each do |key|
              if value = Split.redis.hget("user_store:#{session[:split]}", key)
                Split.redis.hset("user_store:#{current_user.id}", key, value)
              end
            end
            confirmjs = Split.redis.get("user_store:#{session[:split]}:confirmed")
            Split.redis.set("user_store:#{current_user.id}:confirmed", confirmjs) unless confirmjs.nil?
          end
          if session[:split] > User.last.id
            Split.redis.del("user_store:#{session[:split]}")
            Split.redis.del("user_store:#{session[:split]}:confirmed")
          end
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