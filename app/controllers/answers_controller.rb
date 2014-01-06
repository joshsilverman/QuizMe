class AnswersController < ApplicationController
  before_filter :admin?, :except => [:update]

  def update
    @answer = Answer.find(params[:id])
    @answer.question.update bad_answers: nil
    @answer.question.update(status: 0) unless current_user.is_role? 'admin' or current_user.is_role? 'asker' 
    redirect_to "/" unless @answer
    
    if @answer.update_attributes(params[:answer])
      head :ok
    else
      render json: @answer.errors, status: :unprocessable_entity
    end
  end
end
