class IssuancesController < ApplicationController

  def show
    respond_to do |format|
      format.html {}
      format.json do
        issuance = Issuance.find(params[:id])

        json = issuance.to_json(
          only: [:created_at],
          include: {
            badge: {only: [:title, :description, :filename]}, 
            user: {only: [:twi_screen_name, :twi_profile_img_url]}
        })
        render json: json
      end
    end
  end
end
