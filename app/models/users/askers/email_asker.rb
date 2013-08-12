class EmailAsker < Asker

	def send_public_message text, options = {}, recipient = nil
    if recipient
      send_private_message recipient, text, options
    else
      raise "no recipient to degrade public to private send"
    end
	end

	def send_private_message recipient, text, options = {}
    text, url = choose_format_and_send recipient, text, options
    Post.create(
      :user_id => self.id,
      :provider => 'twitter',
      :text => text,
      :in_reply_to_post_id => options[:in_reply_to_post_id],
      :in_reply_to_user_id => recipient.id,
      :conversation_id => options[:conversation_id],
      :url => url,
      :posted_via_app => true,
      :requires_action => false,
      :interaction_type => 5,
      :intention => options[:intention],
      :nudge_type_id => options[:nudge_type_id],
      :question_id => options[:question_id], 
      :is_reengagement => options[:is_reengagement]
    )
	end

  def choose_format_and_send recipient, text, options
    if options[:question_id]
      question = Question.includes(:answers).find(options[:question_id])
      mail, text, url = EmailAskerMailer.question(self, recipient, text, question, options)
      mail .deliver
      return text, url
    else
      false
    end
  end
end