class RegistrationsController < Devise::RegistrationsController

  def create
    user = nil
    User.transaction do
      super

      last_user = User.last
      if last_user.email == params[:user][:email]
        user = last_user
      # else
      #   binding.pry
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