module EngagementEngine::AutoRespond

  def auto_respond user_post
    return unless !user_post.autocorrect.nil? and user_post.requires_action
    
    answerer = user_post.user  
    if user_post.is_dm?
      return unless answerer.dm_conversation_history_with_asker(id).grade.blank?
      return if user_post.is_moderatable? and rand <= 0.05
      interval = Post.create_split_test(
        answerer.id, 
        "DM autoresponse interval v2 (activity segment +)", 
        "90", "120", "150", "180", "210")

      Delayed::Job.enqueue(
        TwitterPrivateMessage.new(self, answerer, generate_response(user_post.autocorrect, user_post.in_reply_to_question), {:in_reply_to_post_id => user_post.id, :intention => "dm autoresponse"}),
        :run_at => interval.to_i.minutes.from_now)
      
      user_post.update_attribute :correct, user_post.autocorrect
      learner_level = "dm answer"
    else
      return unless user_post.conversation.posts.grade.blank?
      return if user_post.is_moderatable? and rand <= 0.05
      root_post = user_post.conversation.post
      asker_response = app_response(user_post, user_post.autocorrect, {
        :link_to_parent => false, 
        :autoresponse => true,
        :post_to_twitter => true,
        :quote_user_answer => root_post.is_question_post? ? true : false,
        :link_to_parent => root_post.is_question_post? ? false : true
      })
      conversation = user_post.conversation || Conversation.create(:publication_id => user_post.publication_id, :post_id => user_post.in_reply_to_post_id, :user_id => user_post.user_id)
      conversation.posts << user_post
      conversation.posts << asker_response
      learner_level = "twitter answer"
    end
    after_answer_filter(answerer, user_post, :learner_level => learner_level)
  end

end