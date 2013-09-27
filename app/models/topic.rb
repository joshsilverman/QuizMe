class Topic < ActiveRecord::Base
	has_many :search_term_users, foreign_key: :search_term_topic_id, class_name: 'User'

	has_and_belongs_to_many :questions, -> { uniq }
	has_and_belongs_to_many :askers, -> { uniq }, join_table: :askers_topics

	scope :descriptions, -> { where("type_id = 1") } # can be dropped into a sentence like: "Learn about ___." 
	scope :hashtags, -> { where("type_id = 2") }
	scope :search_terms, -> { where("type_id = 3") }
	scope :categories, -> { where("type_id = 4") }
	scope :courses, -> { where("type_id = 5") }
	scope :lessons, -> { where("type_id = 6") }

	def lessons # returns a course's lessons
		return nil unless type_id == 5
		questions.includes(:topics).collect { |q| q.topics.select { |t| t.type_id == 6 } }.flatten.uniq
	end	

	def courses # returns courses to which a lesson belongs
		return nil unless type_id == 6
		questions.includes(:topics).collect { |q| q.topics.select { |t| t.type_id == 5 } }.flatten.uniq
	end

	# intended only for use with lesson/course/category types
	def percentage_completed_by_user user
		question_ids = questions.collect &:id
		return 1.0 if question_ids.count == 0
		
		question_count = question_ids.count
		correctly_answered_questions = Question.joins(:in_reply_to_posts).where('questions.id' => question_ids).where('posts.user_id' => user.id, 'posts.correct' => true).group('questions.id')
		correctly_answered_questions.to_a.count / question_count.to_f
	end
end