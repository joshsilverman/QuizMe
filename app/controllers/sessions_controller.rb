class SessionsController < Devise::SessionsController
  def new
    # choose random asker for styling
    @asker = Asker.published.sample
    @asker.subject = 'Sign In'

    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)

    respond_to do |format|
      format.html.phone do
        render :new, layout: 'phone'
      end
      
      format.html.none {}
    end
  end

  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message(:notice, :signed_in) if is_navigational_format?
    sign_in(resource_name, resource)

    respond_to do |format|
      format.html.phone do
        redirect_to controller: 'users', action: 'auth_token'
      end
      
      format.html.none { redirect_to after_sign_in_path_for(resource) }
    end
  end
end
