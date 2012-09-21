class Answer < ActiveRecord::Base
	include ActionView::Helpers::TextHelper
	belongs_to :question

	def self.correct
		where(:correct => true).first
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
