class Transition < ActiveRecord::Base
	belongs_to :user

	def segment
		case self.segment_type
		when 1
			puts 'lifecycle'
		when 2
			puts 'activity'
		when 3
			puts 'interaction'
		when 4
			puts 'author'
		end
	end
end
