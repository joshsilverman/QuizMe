class EmailAskersController < ApplicationController
	# skip filters designed for humans
	skip_before_filter :referrer_data

  def save_private_response
    begin
    	handle = Mail::Address.new(params[:to]).local
      user = User.find_by_email Mail::Address.new(params[:from]).address
      asker = EmailAsker.tfind(handle)
      asker.delay.save_post(params, user) if asker
    rescue ArgumentError => exception
      puts "argument error in save_private_response: #{exception}"
    end

    render text: nil, status: 200
  end
end