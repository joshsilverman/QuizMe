class IssuancesController < ApplicationController

  def show
    @issuance = Issuance.includes(:badge, :user, :asker).find(params[:id])

    @json = @issuance.to_json(
      only: [:created_at],
      include: {
        badge: {only: [:title, :description, :filename]}, 
        user: {only: [:twi_screen_name, :twi_profile_img_url]},
        asker: {only: [:twi_screen_name]}
    })

    respond_to do |format|
      format.html {}
      format.json { render json: @json }
    end
  end
end
