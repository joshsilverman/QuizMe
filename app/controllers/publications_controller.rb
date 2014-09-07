class PublicationsController < ApplicationController
  def show
    publication = Publication.where(id: params[:id]).first

    respond_to do |format|
      format.json do
        if publication
          render json: publication.to_json
        else
          head 404
        end
      end
    end
  end
end
