class QuestionObserver < ActiveRecord::Observer
  def after_create(question)
    return if question.user_id.nil?
    question.delay.post
  end

  def after_save question
    question.topics.lessons.each do |lesson|
      lesson.update_question_count
    end
  end
end