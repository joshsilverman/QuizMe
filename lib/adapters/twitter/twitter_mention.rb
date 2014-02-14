class TwitterMention
	def initialize sender, text, options = {}
		@sender = sender
		@text = text
		@options = options
	end

  def perform
    @sender.send_public_message(@text, @options)
    
    if @options[:intention] == 'incorrect answer follow up'
      MP.track_event "incorrect answer follow up sent", {:distinct_id => @options[:in_reply_to_user_id]}
    end
  end

  def max_attempts
    return 3
  end
end