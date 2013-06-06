class TwitterMention
	def initialize sender, text, options = {}
		@sender = sender
		@text = text
		@options = options
	end

  def perform
    Post.tweet(@sender, @text, @options)
    
    if @options[:intention] == 'incorrect answer follow up'
      Mixpanel.track_event "incorrect answer follow up sent", {:distinct_id => options[:in_reply_to_user_id]}
    end
  end
end