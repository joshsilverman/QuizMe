class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :referrer_data
  before_filter :preload_models
  before_action :set_variant

  force_ssl if: :ssl_configured?

  def ssl_configured?
    Rails.env.production?
  end
  
  def set_variant
    if request.headers['HTTP_WISR_VARIANT']
      request.variant = request.headers['HTTP_WISR_VARIANT'].to_sym
    elsif session[:variant]
      request.variant = session[:variant].to_sym
    elsif params[:variant]
      if params[:variant].is_a? Array
        request.variant = params[:variant].first.to_sym
      else
        request.variant = params[:variant].to_sym
      end
    end

    if request.variant
      session[:variant] = request.variant.first.to_s
    end
  end

  def check_for_authentication_token
    if !current_user and params["a"]
      auth_hash = Rack::Utils.parse_nested_query(Base64.decode64(params["a"]))
      return unless auth_hash["authentication_token"] and auth_hash["expires_at"]
      return unless Time.now < Time.at(auth_hash["expires_at"].to_i)
      user = User.find_by(authentication_token: auth_hash["authentication_token"])
      return unless user
      sign_in :user, user
    end
  end

  def after_sign_in_path_for resource, redirect_to = nil
    oauth_params = request.env["omniauth.params"]
    if oauth_params
      if oauth_params["feed_id"]
        if oauth_params['feed_id'] == "8765"
          redirect_to = "/feeds/index/#{oauth_params['publication_id']}"
        else
          if oauth_params["q"] == "1"
            redirect_to = "/feeds/#{oauth_params['feed_id']}?q=1"
          else
            redirect_to = "/feeds/#{oauth_params['feed_id']}"\
              + "/#{oauth_params['publication_id']}"\
              + "/#{oauth_params['answer_id']}"
          end
        end      
      elsif oauth_params['asker_id']
        redirect_to = "/askers/#{oauth_params['asker_id']}/questions"
      else
        redirect_to = request.env['omniauth.origin'] || session[:return_to] || root_path
      end
    else
      redirect_to = root_path
    end

    redirect_to
  end  

  def after_sign_out_path_for resource, redirect_to = nil
    # request.referer || root_path
    root_path
  end    

  # preload models so caching works in development
  # http://aaronvb.com/articles/37-rails-caching-and-undefined-class-module
  def preload_models
    if Rails.env == "development"
      Dir[Rails.root.join('app', 'models', '{**.rb}')].each do |model_name|
        require_dependency model_name unless model_name == "." || model_name == ".." || model_name == ".gitkeep" || model_name == ".DS_Store"
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

  def moderator?
    session[:return_to] = request.fullpath
    if current_user
      redirect_to '/' unless current_user.is_role? "moderator" or current_user.is_role? "admin"
      return current_user.is_role? "moderator"
    else
      redirect_to user_omniauth_authorize_path(:twitter, use_authorize: false)
      return false
    end
  end

  def set_session_variables
    if params["lt"] == "reengage" and params[:post_id].present?
      session[:reengagement_publication_id] = params[:post_id] 
      session[:referring_user] = params["t"]
    end
  end

private

  def referrer_data
    @campaign = params[:c]
    @source = params[:s]
    @link_type = params[:lt]
  end
end