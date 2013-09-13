class EmailAskersController < ApplicationController
	# skip filters designed for humans
	skip_before_filter :referrer_data, :split_user

  def save_private_response
    puts 'in save_private_response'
    puts params['text']
    puts params['text'].include?('�')
    params['text'] = params['text'].gsub('é', 'e').gsub('ó', 'o').gsub('á', 'a').gsub('í', 'i').gsub('å', 'a')

  	handle =  Mail::Address.new(params[:to]).local
    user = User.find_by_email Mail::Address.new(params[:from]).address
    asker = EmailAsker.tfind(handle)
    asker.delay.save_post(params, user) if asker

    render text: nil, status: 200
  end
end