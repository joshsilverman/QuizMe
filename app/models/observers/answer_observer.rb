class AnswerObserver < ActiveRecord::Observer
  def after_save(answer)
    return if !answer.question
    
    answer.question.update_answers
  end
end