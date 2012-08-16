class Topic < ActiveRecord::Base
	has_many :users, :through => :askertopics
	has_many :askertopics
	has_many :questions

	def askers
		users
	end

end