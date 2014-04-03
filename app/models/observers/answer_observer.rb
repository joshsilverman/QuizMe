class AnswerObserver < ActiveRecord::Observer
  def after_save(answer)
    answer.question.update_answers
  end
end