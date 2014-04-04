class AnswerObserver < ActiveRecord::Observer
  def after_save(answer)
    answer.question.delay.update_answers
  end
end