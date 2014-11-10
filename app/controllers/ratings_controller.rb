class RatingsController < ApplicationController
  before_filter :authenticate_user!
  skip_before_filter :verify_authenticity_token

  def create
    @rating = Rating.find_or_initialize_by(
      user_id: current_user.id,
      question_id: rating_params[:question_id])
    @rating.score = rating_params[:score]

    if @rating.save
      MP.track_event "rated question", {
        distinct_id: current_user.id,
        score: @rating.score,
        question_id: rating_params[:question_id]}

      head 200
    else
      head 400
    end
  end

  def index
    render json: current_user.ratings.to_json
  end

  private
    def rating_params
      params.permit(:score, :question_id)
    end
end
