class RegistrationsController < Devise::RegistrationsController

  def new
    self.resource = resource_class.new(devise_parameter_sanitizer.for(:sign_in))
    clean_up_passwords(resource)

    respond_to do |format|
      format.html.phone do
        render layout: 'phone'
      end
      
      format.html.none {}
    end
  end

  def create
    user = nil
    User.transaction do
      super

      last_user = User.last
      if last_user.email == params[:user][:email]
        user = last_user
      end
    end

    respond_to do |format|
      format.html.phone do
        if user
          user.update communication_preference: 3
        end
      end

      format.html.none do
        if user
          user.update communication_preference: 2
        end
      end
    end
  end
end