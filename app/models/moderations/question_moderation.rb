class QuestionModeration < Moderation
	default_scope where('question_id is not null')
	belongs_to :question

	scope :publishable, where(type_id: 7)
	scope :innacurate, where(type_id: 8)
	scope :errors, where(type_id: 9)
	scope :incomplete, where(type_id: 10)
end