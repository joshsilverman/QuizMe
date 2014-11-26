class AnswersController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:update]
  before_filter :authenticate_user!

  def update
    answer = Answer.find(params[:id])
    question = current_user.questions.where(id: answer.question_id).first
    question ||= Question.find(answer.question_id) if current_user.is_role? "admin"
    if !question
      head :unauthorized
      return
    end

    question.update bad_answers: nil
    question.update(status: 0) unless current_user.is_role? 'admin' or current_user.is_role? 'asker' 
    redirect_to "/" unless answer

    # standardize params    
    if params[:answer]
      params[:answer].each { |k,v| params[k] = v }
    end
    safe_params = params.permit(:correct, :question_id, :text)

    if answer.update(safe_params)
      render json: answer
    else
      render json: answer.errors, status: :unprocessable_entity
    end
  end
end
