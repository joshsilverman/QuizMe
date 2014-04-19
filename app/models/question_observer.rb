class QuestionObserver < ActiveRecord::Observer
  def after_create(question)
    if Rails.env.test? or Post.create_split_test(question.user_id, "request immediate feedback on author's questions (return submission)", 'true', 'false') == 'true'
      return if question.user_id.nil?

      question.asker.delay.request_feedback_on_question(question)
    end
  end
end