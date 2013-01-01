class AnswersController < ApplicationController
  before_filter :admin?

  def update
    @answer = Answer.find(params[:id])
    redirect_to "/" unless @answer

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
