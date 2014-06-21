class RegistrationsController < Devise::RegistrationsController

  def new
    self.resource = resource_class.new(devise_parameter_sanitizer.for(:sign_in))
    clean_up_passwords(resource)
    @asker = Asker.published.sample

    respond_to do |format|
      format.html.phone do
        render layout: 'phone'
      end
      
      format.html.none {}
    end
  end

  def create
    @asker = Asker.published.sample
    build_resource(sign_up_params)

    if request.variant and request.variant.include? :phone
      resource.communication_preference = 3
    else
      resource.communication_preference = 2
    end

    if resource.save
      if resource.active_for_authentication?
        sign_up(resource_name, resource)
        respond_with resource, :location => after_sign_up_path_for(resource)
      else
        expire_session_data_after_sign_in!
        respond_with resource, :location => after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      respond_to do |format|
        format.html.phone { render :new, layout: 'phone' }
        format.html.none { render :new }
      end
    end
  end
end