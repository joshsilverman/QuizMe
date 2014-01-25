module EngagementEngine::Utils::Linker

  # formally in_answer_to_question
  def link_to_question amatch = false
    return in_reply_to_question unless in_reply_to_question.nil? or amatch == true

    conversation = self.conversation # this only became necessary when factoring this into a module
    if interaction_type == 3
      # retweet
    elsif parent and parent.question
      _in_reply_to_question = parent.question
    elsif interaction_type == 4 and conversation and conversation.post and conversation.post.user and conversation.post.user.is_role? "asker"
      asker = Asker.find(conversation.post.user_id)
      _in_reply_to_question = asker.posts.includes(:question).dms.where("in_reply_to_user_id = ? and intention = 'initial question dm'", user_id).first.try(:question)
    elsif conversation and conversation.publication and conversation.publication.question
      _in_reply_to_question = conversation.publication.question
    elsif parent and parent.publication and parent.publication.question
      _in_reply_to_question = parent.publication.question
    end

    if _in_reply_to_question.nil? or amatch == true
      _in_reply_to_question = link_by_amatch
    end

    self.update_attribute :in_reply_to_question_id, _in_reply_to_question.id if _in_reply_to_question
    in_reply_to_question
  end

  def link_by_amatch
    _in_reply_to_question = nil

    askers = Asker.select([:twi_screen_name]).collect(&:twi_screen_name).join('|')
    reengagement = "@[^\\s]+ (?:Next question!|A question for you:|Pop quiz:|Do you know the answer\\?|Quick quiz:|)\\s?"
    re_with_url = /@(?:#{askers})[\s:]*\s(?:#{reengagement})?([\w\W]+?)(?:http:)[\w\W]*$/
    re_without_url = /@(?:#{askers})[\w|:]*\s(?:#{reengagement})?([\w\W]+?)$/

    match = text.match(re_with_url) || text.match(re_without_url)
    
    if match
      stripped_text = match[1]
      @asker = Asker.find_by(id: in_reply_to_user_id)

      if @asker
        scores = {}
        @asker.questions.each do |q|
          scores[Post.grader.longest_substring q.text, stripped_text] = q
        end
        
        if scores.keys.count > 0 and scores.keys.max > 0.7
          _in_reply_to_question = scores[scores.keys.max] 
          Tag.find_or_create_by(name: 'auto-linked').posts << self

          #mimic normal conversation
          publication = self.publication || _in_reply_to_question.publications.order('created_at DESC').limit(1).first
          return unless publication

          post = publication.posts.where('posts.created_at < ?', created_at).order("posts.created_at DESC").first
          return unless post

          conversation = Conversation.create(:publication_id => publication.id, :post_id => post.id, :user_id => user_id)
          update_attributes({
            publication_id: publication.id,
            in_reply_to_post_id: post.id,
            in_reply_to_user_id: post.user_id,
            conversation_id: conversation.id
          })
        end
      end
    end

    _in_reply_to_question
  end
end