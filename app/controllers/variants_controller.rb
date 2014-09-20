class VariantsController < ApplicationController

  def current
    variant = ""
    if request.variant.present?
      variant = request.variant.first.to_s
    end

    render text: variant
  end
end
