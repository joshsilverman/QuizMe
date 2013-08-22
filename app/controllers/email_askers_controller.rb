class EmailAskersController < ApplicationController
	# skip filters designed for humans
	skip_before_filter :referrer_data, :split_user

  def save_private_response
    params['text'] = params['text'].encode('utf-8', 'iso-8859-1')
  	handle =  Mail::Address.new(params[:to]).local
    user = User.find_by_email Mail::Address.new(params[:from]).address
    
    asker = EmailAsker.tfind(handle)

    post = asker.save params, user

    Post.classifier.classify post
    Post.grader.grade post.reload

    asker.auto_respond post.reload, user, params

    render text: nil, status: 200
  end
end