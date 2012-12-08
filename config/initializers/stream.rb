TweetStream.configure do |config|
  config.consumer_key       = 'tPuU2krUmUKdeQ8VQBjN9g'
  config.consumer_secret    = 'InlkWLx15C5IOKqPBqPKEXHxlEz7ZrrlzKLP2LmVePw'
  config.oauth_token        = '612050283-huCJeIt3MltG0ga2eq9rm9oWuGigIP68DL3cyZOP'
  config.oauth_token_secret = 'U0t08RRtyfBefNI2PlzZc6wMmBdADIBAqi4piIahBs'
  config.auth_method        = :oauth
end	

streaming_account = User.find(18)

Thread.new {
	client = TweetStream::Client.new

	client.on_direct_message do |direct_message|
		Post.save_post(4, direct_message, streaming_account.id)
	end

	client.on_timeline_status do |status|
		if status.retweeted_status and status.retweeted_status.user.id == streaming_account.twi_user_id
			Post.save_post(3, status, streaming_account.id)
		elsif status.user_mentions.select{ |e| e.id == streaming_account.twi_user_id }.present?
			Post.save_post(2, status, streaming_account.id)
	  end
	end

	client.on_error do |error|
		puts "error in stream: #{error.to_json}"
	end

	client.on_limit do |error|
		puts "limit in stream: #{error.to_json}"
	end	

	client.userstream	
}