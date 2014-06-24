class IphoneAsker < Asker

	def send_public_message text, options = {}, recipient = nil
	end

	def send_private_message recipient, text, options = {}
	end

  def auto_respond post, answerer, params = {}
  end
end