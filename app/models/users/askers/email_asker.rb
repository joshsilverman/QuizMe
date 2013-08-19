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
      :provider => 'email',
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
      :publication_id => options[:publication_id],
      :is_reengagement => options[:is_reengagement]
    )
	end

  def save params, u
    in_reply_to_post_id = detect_in_reply_to_post_id params[:text], u

    if in_reply_to_post_id
      in_reply_to_post = Post.find in_reply_to_post_id
      conversation_id = in_reply_to_post.conversation_id || Conversation.create(:post_id => in_reply_to_post.id, :user_id => u.id).id
    end
    conversation_id ||= nil

    Post.create(
      :text => params[:text],
      :provider => 'email',
      :user_id => u.id,
      :in_reply_to_post_id => in_reply_to_post_id,
      :in_reply_to_user_id => id,
      :conversation_id => conversation_id,
      :posted_via_app => false,
      :interaction_type => 5,
      :requires_action => true
    )
  end

  def email pretty = true
    if pretty 
      "#{twi_screen_name} <#{twi_screen_name}@app.wisr.com>"
    else
      "#{twi_screen_name}@app.wisr.com"
    end
  end

  def auto_respond post, answerer, params
    return unless !post.autocorrect.nil? and post.requires_action
    return unless post.conversation.posts.grade.blank?

    text = generate_response post.autocorrect, post.in_reply_to_question, true
    send_private_message answerer, text, {
      :user_id => id,
      :provider => 'email',
      :in_reply_to_post_id => post.id,
      :in_reply_to_user_id => answerer.id,
      :conversation_id => post.conversation.id,
      :intention => 'grade',
      :question_id => post.in_reply_to_question_id,
      :publication_id => post.conversation.post.publication.id,
      :subject => params[:subject]
    }

    learner_level = "twitter answer"
    after_answer_filter(answerer, post, :learner_level => learner_level)
  end

  def choose_format_and_send recipient, text, options
    if options[:is_reengagement] and options[:question_id]
      question = Question.includes(:answers).find(options[:question_id])
      short_url = nil
      if options[:short_url]
        short_url = options[:short_url]
      elsif options[:long_url]
        short_url = Post.format_url(options[:long_url], 'email', options[:link_type], twi_screen_name, recipient.twi_screen_name) 
      end      
      mail, text, url = EmailAskerMailer.question(self, recipient, text, question, short_url, options)
      mail.deliver
      return text, url
    elsif options[:intention] == 'grade'
      short_url = nil
      if options[:short_url]
        short_url = options[:short_url]
      elsif options[:long_url]
        short_url = Post.format_url(options[:long_url], 'email', options[:link_type], twi_screen_name, recipient.twi_screen_name) 
      end
      mail, text, url = EmailAskerMailer.generic(self, recipient, text, short_url, options)
      mail.deliver
      return text, url
    else
      false
    end
  end

  def detect_in_reply_to_post_id text, user
    if match = text.match(/http:\/\/wisr.com\/feeds\/([0-9]+)\/([0-9]+)\?s=[a-zA-Z]+&lt=reengage/)
      url, asker_id, pub_id = match.to_a
      post_id = Publication.find(pub_id.to_i).posts.where(in_reply_to_user_id: user.id).last.id
      return post_id if id == asker_id.to_i
    else
    end
  end
end