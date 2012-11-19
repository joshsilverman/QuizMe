class RateSheetsController < ApplicationController
  before_filter :admin?
  
  def update
    @rate_sheet = RateSheet.find(params[:id])

    respond_to do |format|
      if @rate_sheet.update_attributes(params[:rate_sheet])
        format.html { redirect_to @rate_sheet, notice: 'Rate Sheet was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @rate_sheet.errors, status: :unprocessable_entity }
      end
    end
  end
end
