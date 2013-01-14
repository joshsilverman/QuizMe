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

	def is_positive?
		return true if SEGMENT_HIERARCHY[segment_type].index(from_segment).nil? or SEGMENT_HIERARCHY[segment_type].index(to_segment) > SEGMENT_HIERARCHY[segment_type].index(from_segment)
		false
	end
end
