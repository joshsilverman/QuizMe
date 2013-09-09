class QuestionObserver < ActiveRecord::Observer
  def after_create(question)
  	# check env for testing purposes
  	if Rails.env.test? or Post.create_split_test(question.user_id, "request immediate feedback on author's questions (return submission)", 'true', 'false') == 'true'
			question.asker.delay.request_feedback_on_question(question)
		end
  end
end