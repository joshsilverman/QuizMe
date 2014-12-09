class AnswersController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:create, :update, :destroy]
  before_filter :authenticate_user!
  before_filter :verify_author!

  def create
    respond_to do |format|
      format.json do
        question = Question.find(params[:question_id])

        safe_params = params.permit(:text, :correct)
        answer = question.answers.new safe_params

        if answer.save
          render json: answer
        else
          render json: answer.errors
        end
      end
    end
  end

  def update
    answer = Answer.find(params[:id])
    question = Question.find(answer.question_id)
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

  def destroy
    answer = Answer.find(params[:id])

    respond_to do |format|
      format.json do
        if answer.destroy
          head :ok
        else
          head :unprocessable_entity
        end
      end
    end
  end

  private

  def verify_author!
    if params[:id]
      answer = Answer.find(params[:id])
      question_id = answer.question_id
    elsif params[:question_id]
      question_id = params[:question_id]
    end
        
    if current_user.questions.where(id: question_id).first
    elsif current_user.is_role? 'admin'
    else
      head :unauthorized
    end
  end
end
