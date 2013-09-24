class Topic < ActiveRecord::Base
	has_many :search_term_users, foreign_key: :search_term_topic_id, class_name: 'User'

	has_and_belongs_to_many :questions
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
end