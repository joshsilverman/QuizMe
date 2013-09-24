class EmailAsker < Asker

	def send_public_message text, options = {}, recipient = nil
    recipient ||= User.where(id: options[:in_reply_to_user_id]).first
    if recipient
      send_private_message recipient, text, options
    else
      raise "no recipient to degrade public to private send"
    end
	end

	def send_private_message recipient, text, options = {}
    return unless EmailAsker.should_send_as_email? options[:intention]
    text, url = choose_format_and_send(recipient, text, options)
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
    
    Post.find(options[:in_reply_to_post_id]).update(requires_action: false) if options[:in_reply_to_post_id]
	end

  def self.should_send_as_email? intention
    benned_intention_types = ['post aggregate activity']
    !benned_intention_types.include? intention
  end

  def save_post params, user
    in_reply_to_post_id = detect_in_reply_to_post_id(params[:text], user)

    conversation_id = nil
    if in_reply_to_post_id
      in_reply_to_post = Post.find in_reply_to_post_id
      conversation_id = in_reply_to_post.conversation_id || Conversation.create(:post_id => in_reply_to_post.id, :user_id => user.id, :publication_id => in_reply_to_post.publication_id).id
    end

    post = Post.create(
      :text => params[:text].split(/(\r|\n)/)[0],
      :provider => 'email',
      :user_id => user.id,
      :in_reply_to_post_id => in_reply_to_post_id,
      :in_reply_to_user_id => id,
      :conversation_id => conversation_id,
      :posted_via_app => false,
      :interaction_type => 5,
      :requires_action => true
    )

    next_question(user) if post.text.downcase.strip == 'next'

    Post.classifier.classify post
    Post.grader.grade post.reload
    
    auto_respond post.reload, user, params   
  end

  def email pretty = true
    if pretty 
      "#{twi_screen_name} <#{twi_screen_name}@app.wisr.com>"
    else
      "#{twi_screen_name}@app.wisr.com"
    end
  end

  def auto_respond post, answerer, params = {}
    return unless !post.autocorrect.nil? and post.requires_action
    # return unless post.conversation.posts.grade.blank?

    post.update(correct: post.autocorrect)

    text = generate_response post.autocorrect, post.in_reply_to_question, true

    # select followup question
    question = select_question(answerer)
    publication = question.publications.published.order("created_at DESC").first
    long_url = publication ? "http://wisr.com/feeds/#{id}/#{publication.id}" : "http://wisr.com/questions/#{question.id}/"

    send_private_message(answerer, text, {
      :user_id => id,
      :provider => 'email',
      :in_reply_to_post_id => post.id,
      :in_reply_to_user_id => answerer.id,
      :conversation_id => post.conversation.id,
      :intention => 'grade',
      :in_reply_to_question_id => post.in_reply_to_question_id,
      :question_id => question.id,
      :publication_id => publication.try(:id),
      :subject => params[:subject],
      :long_url => long_url,
      :include_answers => true
    })

    learner_level = "twitter answer"
    after_answer_filter(answerer, post, :learner_level => learner_level)
    # ask_question(answerer) if post.is_email? and answerer.prefers_email?
  end

  def choose_format_and_send recipient, text, options
    options[:short_url] = Post.format_url(options[:long_url], 'email', options[:link_type], twi_screen_name, recipient.twi_screen_name) if options[:short_url].blank? and options[:long_url]

    if options[:question_id]
      question = Question.includes(:answers).find(options[:question_id])
      mail = EmailAskerMailer.question(self, recipient, text, question, options[:short_url], options)
      mail.deliver
      return text, options[:short_url]
    else
      mail = EmailAskerMailer.generic(self, recipient, text, options[:short_url], options)
      mail.deliver
      return text, options[:short_url]
    end
  end

  def detect_in_reply_to_post_id text, user
    if match = text.match(/http:\/\/wisr.com\/feeds\/([0-9]+)\/([0-9]+)/)
      url, asker_id, pub_id = match.to_a
      post_id = Publication.find(pub_id.to_i).posts.where("interaction_type = 5").where(in_reply_to_user_id: user.id).last.try(:id)
      return (id == asker_id.to_i and post_id) ? post_id : nil
    elsif match = text.match(/http:\/\/wisr.com\/questions\/([0-9]+)/)
      return Post.email.where(question_id: match[1], in_reply_to_user_id: user.id).last.try(:id)
    else
    end
  end

  def select_question user
    # @todo TEMPORARY, ADD APPROPRIATE FIND
    question_ids_answered = get_question_ids_answered(user)
    course = Topic.courses.first 
    lesson = select_lesson(user, course)
    lesson_question_ids = lesson.questions.sort.collect(&:id)
    return Question.find((lesson_question_ids - question_ids_answered).first)
  end

  def select_lesson user, course
    question_ids_answered = get_question_ids_answered(user)
    course.lessons.sort.each do |lesson|
      lessons_questions_ids = lesson.questions.collect(&:id)
      return lesson if (lessons_questions_ids - question_ids_answered).present?
    end
  end

  def get_question_ids_answered user
    @question_ids_answered ||= user.posts.answers.where(in_reply_to_user: self).collect(&:in_reply_to_question_id).uniq
  end
end