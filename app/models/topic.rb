class Topic < ActiveRecord::Base
	has_many :users, :through => :askertopics
	has_many :askertopics
	has_many :questions

	scope :descriptions, where("type_id = 1") # can be dropped into a sentence like: "Learn about ___."
	scope :hashtags, where("type_id = 2")
	scope :search_terms, where("type_id = 3")
	scope :categories, where("type_id = 4")

	def askers
		users
	end

end