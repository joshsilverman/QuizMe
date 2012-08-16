class Answer < ActiveRecord::Base
	include ActionView::Helpers::TextHelper
	belongs_to :question

	def self.correct
		where(:correct => true).first
	end

	def tweetable(asker_name)
		length = self.text.length
		overage = (140 - asker_name.length - 2 - length)
		overage < 0 ? truncate = length - overage.abs : truncate = length		
		truncate(self.text, :length => truncate)
	end
end
