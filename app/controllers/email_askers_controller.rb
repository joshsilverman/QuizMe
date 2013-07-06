class EmailAskersController < ApplicationController
  def save_private_response
    handle = params[:to].split('@').first
    user = User.find_by_email params[:from]
    asker = Asker.tfind(handle).first

    # post = asker.save_email params, user

    # asker.auto_respond post

    render text: nil
  end
end