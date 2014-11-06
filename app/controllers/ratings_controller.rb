class RatingsController < ApplicationController
  before_filter :authenticate_user!

  def create
    @rating = Rating.find_or_initialize_by(
      user_id: current_user.id,
      question_id: rating_params[:question_id])
    @rating.score = rating_params[:score]

    if @rating.save
      head 200
    else
      head 400
    end
  end

  private
    def rating_params
      params.permit(:score, :question_id)
    end
end
