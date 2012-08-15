class Topic < ActiveRecord::Base
	has_many :askers, :through => :askertopics, :source => 'User'
	# has_many :askertopics
end
