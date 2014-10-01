class IphoneAsker < Asker

  INTENTION_WHITELIST = ['incorrect answer follow up', 'reengage inactive']

	def send_public_message text, options = {}, recipient = nil
    if recipient
      send_private_message recipient, text, options
    else
      return nil
    end
	end

	def send_private_message recipient, text, options = {}
    if options[:is_reengagement]
      MP.track_event "reengaged inactive (iphone_asker#send_public_message)", {
        token_nil: recipient.device_token.nil?,
        intention: options[:intention],
        not_white_listed_intention: !INTENTION_WHITELIST.include?(options[:intention])
      }
    end

    return nil if recipient.device_token.nil?
    return nil if !INTENTION_WHITELIST.include?(options[:intention])

    notification = Houston::Notification.new(device: recipient.device_token)
    notification.alert = text

    if options[:question_id]
      bg_color = '292935'
      bg_color = self.styles['bg_color'].gsub('#', '') if self.styles

      notification.custom_data = {
        path: "question",
        question_id: options[:question_id],
        asker_id: self.id,
        bg_color: bg_color}
    end

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
