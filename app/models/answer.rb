class Answer < ActiveRecord::Base
	belongs_to :question

	def self.correct
		where(:correct => true).first
	end

	def tweetable(asker_name)
		puts asker_name
	end
end
