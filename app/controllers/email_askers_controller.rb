class EmailAskersController < ApplicationController
  def save_private_response
    puts params.to_yaml
    render text: "hello"
  end
end