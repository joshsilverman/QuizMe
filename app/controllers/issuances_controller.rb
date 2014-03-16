class IssuancesController < ApplicationController

  before_filter :authenticate_user!, except: [:show]

  def show
    @issuance = Issuance.includes(:badge, :user, :asker).find(params[:id])
    @asker = @issuance.asker

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

  def index
    @user = User.where(id: current_user.id)
      .includes(issuances: [:badge]).first

    @json = @user.issuances.to_json(
      only: [:id],
      include: {
        badge: {only: [:title, :description, :filename]}
    })

    respond_to do |format|
      format.json { render json: @json }
    end
  end
end
