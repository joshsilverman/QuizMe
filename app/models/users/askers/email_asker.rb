class EmailAsker < Asker

	def public_send text, options = {}, recipient = nil
    if recipient
      private_send recipient, text, options
    else
      raise "no recipient to degrade public to private send"
    end
	end

	def private_send recipient, text, options = {}
    text, url = choose_format_and_send recipient, text, options
    post = Post.create(
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
      :question_id => options[:question_id])
	end

  def save_email params, user
    # in_reply_to_post = Post.where()

    # if in_reply_to_post
    #   conversation_id = in_reply_to_post.conversation_id || Conversation.create(:post_id => in_reply_to_post.id, :user_id => u.id).id

    #   # Removes need to hide multiple DMs in same thread
    #   in_reply_to_post.update_attribute(:requires_action, false)
    # else
    #   conversation_id = nil
    #   puts "No in reply to dm"
    # end

    # # possible issue w/ origin dm and its response being collected 
    # # in same rake, then being created in the wrong order
    # post = Post.create( 
    #   :provider_post_id => d.id.to_s,
    #   :text => d.text,
    #   :provider => 'twitter',
    #   :user_id => u.id,
    #   :in_reply_to_post_id => in_reply_to_post.try(:id),
    #   :in_reply_to_user_id => asker.id,
    #   :created_at => d.created_at,
    #   :conversation_id => conversation_id,
    #   :posted_via_app => false,
    #   :interaction_type => 4,
    #   :requires_action => true
    # )

    # u.update_user_interactions({
    #   :learner_level => "dm", 
    #   :last_interaction_at => post.created_at
    # })
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