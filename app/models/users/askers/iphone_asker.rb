class IphoneAsker < Asker

	def send_public_message text, options = {}, recipient = nil
    if recipient
      send_private_message recipient, text, options = {}
    else
      return nil
    end
	end

	def send_private_message recipient, text, options = {}
    return nil if recipient.device_token.nil?

    notification = Houston::Notification.new(device: recipient.device_token)
    notification.alert = text

    APN.push(notification)

    Post.create(
      :user_id => self.id,
      :provider => 'apns',
      :text => text,
      :in_reply_to_post_id => options[:in_reply_to_post_id],
      :in_reply_to_user_id => recipient.id,
      :conversation_id => options[:conversation_id],
      :posted_via_app => true,
      :requires_action => false,
      :interaction_type => 6,
      :intention => options[:intention],
      :nudge_type_id => options[:nudge_type_id],
      :question_id => options[:question_id], 
      :publication_id => options[:publication_id],
      :is_reengagement => options[:is_reengagement]
    )
	end

  def auto_respond post, answerer, params = {}
  end
end