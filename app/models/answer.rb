class Answer < ActiveRecord::Base
	include ActionView::Helpers::TextHelper
	belongs_to :question


	validates :question_id, presence: true
	validate :one_correct_answer_per_question

	def one_correct_answer_per_question
		return if !correct

		question = Question.where(id: question_id).first
		preexisting_correct_answers = question.answers
			.where(correct: true)
			.where('answers.id <> ?', id || 0)
			
		if question and preexisting_correct_answers.present?
			errors.add(:correct, 'Cannot have multiple correct answers')
		end
	end

	def self.correct
		where(:correct => true).first
	end

	def self.incorrect
		where(:correct => false)
	end

	def tweetable(asker_name, url = "")
		answer_length = self.text.length
		asker_length = asker_name.length
		url ? url_length = url.length : url_length = 0
		overage = (140 - asker_length - 1 - answer_length - 1 - url_length - 1)
		overage < 0 ? truncate = answer_length - overage.abs : truncate = answer_length		
		truncate(self.text, :length => truncate)
	end
end
