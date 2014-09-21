class VariantsController < ApplicationController

  def current
    variant = {}
    if request.variant.present?
      variant = {name: request.variant.first.to_s}
    end

    render json: variant
  end
end
