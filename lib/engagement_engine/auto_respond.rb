module EngagementEngine::AutoRespond

  def auto_respond user_post

    return unless !user_post.autocorrect.nil? and user_post.requires_action

    answerer = user_post.user  
    if user_post.is_dm?

      return if already_graded_dm? user_post, answerer
      return if user_post.is_moderatable? and rand <= 0.05

      text = generate_response(
        user_post.autocorrect, 
        user_post.in_reply_to_question)

      self.send_private_message(answerer, text, { 
        in_reply_to_post_id: user_post.id, 
        intention: "grade"})

      user_post.update({
        requires_action: false,
        intention: 'respond to question'})
      learner_level = "dm answer"
    else
      return unless user_post.conversation.posts.grade.blank?
      return if user_post.is_moderatable? and rand <= 0.05
      root_post = user_post.conversation.post
      asker_response = app_response(user_post, user_post.autocorrect, {
        link_to_parent: false, 
        autoresponse: true,
        post_to_twitter: true,
        quote_user_answer: root_post.is_question_post? ? true : false,
        link_to_parent: root_post.is_question_post? ? false : true
      })

      conversation = user_post.conversation || Conversation.create(
        publication_id: user_post.publication_id, 
        post_id: user_post.in_reply_to_post_id, 
        user_id: user_post.user_id)

      conversation.posts << user_post
      conversation.posts << asker_response
      learner_level = "twitter answer"
    end

    after_answer_filter(answerer, user_post, :learner_level => learner_level)
    self.delay.update_metrics(answerer, user_post, nil, {
      autoresponse: true, 
      type: 'twitter'})
  end

  def already_graded_dm? user_post, answerer
    question_post = user_post.parent
    question  = user_post.in_reply_to_question

    already_graded = answerer.posts.dms.where('created_at > ?', question_post.created_at)
      .where(in_reply_to_question: question)
      .where('autocorrect IS NOT NULL')
      .where(requires_action: false)
      .present?

    return already_graded
  end

end