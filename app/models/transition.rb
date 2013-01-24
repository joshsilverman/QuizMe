class Transition < ActiveRecord::Base
	belongs_to :user

	def is_positive?
		return true if SEGMENT_HIERARCHY[segment_type].index(from_segment).nil? or SEGMENT_HIERARCHY[segment_type].index(to_segment) > SEGMENT_HIERARCHY[segment_type].index(from_segment)
		false
	end

	def is_above? above_segment
		return true if SEGMENT_HIERARCHY[segment_type].index(to_segment) > SEGMENT_HIERARCHY[segment_type].index(above_segment)
		false
	end

	def segment
		case self.segment_type
		when 1
			return 'lifecycle'
		when 2
			return 'activity'
		when 3
			return 'interaction'
		when 4
			return 'author'
		end
	end

	# def print segment = "", to = "", from = ""
	# 	case segment_type
	# 	when 1
	# 		segment = 'lifecycle'
	# 	when 2
	# 		segment = 'activity'
	# 	when 3
	# 		segment = 'interaction'
	# 	when 4
	# 		segment = 'author'
	# 	end

	# 	puts "user #{segment} segment transitioned from #{} to #{}"
	# end
end
