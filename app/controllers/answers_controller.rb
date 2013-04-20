class AnswersController < ApplicationController
  before_filter :admin?, :except => [:update]

  def update
    @answer = Answer.find(params[:id])
    redirect_to "/" unless @answer
    
    @answer.question.update_attribute(:status, 0) unless current_user.is_role? 'admin' or current_user.is_role? 'asker' 

    respond_to do |format|
      if @answer.update_attributes(params[:answer])
        format.html { redirect_to @answer, notice: 'Answer was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @answer.errors, status: :unprocessable_entity }
      end
    end
  end
end
