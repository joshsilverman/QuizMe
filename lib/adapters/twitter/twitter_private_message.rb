class TwitterPrivateMessage
	def initialize sender, recipient, text, options = {}
		@sender = sender
		@recipient = recipient
		@text = text
		@options = options
	end

  def perform
    @sender.send_private_message(@recipient, @text, @options)
  end

  def max_attempts
    return 3
  end  
end