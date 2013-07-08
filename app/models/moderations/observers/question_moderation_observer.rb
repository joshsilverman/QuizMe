class QuestionModerationObserver < ActiveRecord::Observer
  # def after_create(question)
  #   question.trigger_response if question.respond_with_type_id
  # end

  # def after_save(question)
  #   question.moderator.becomes(Moderator).update_moderator_segment
  # end  
end