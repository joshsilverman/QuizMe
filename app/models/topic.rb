class Topic < ActiveRecord::Base
	has_many :users, :through => :askertopics
	has_many :askertopics
end
