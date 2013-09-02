class EmailPrivateMessage
	def initialize sender, recipient, text, options = {}
		@sender = sender
    @recipient = recipient
		@text = text
		@options = options
	end

  def perform
    @sender.becomes(EmailAsker).send_private_message(@recipient, @text, @options)
    if @options[:intention] == 'correct answer follow up'
      Mixpanel.track_event "correct answer follow up sent", {:distinct_id => @recipient.id}
    end
  end

  def max_attempts
    return 3
  end
end