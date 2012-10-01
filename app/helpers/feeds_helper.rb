module FeedsHelper
	def eng_name(engagement_type)
		case engagement_type
		when 1 
			return "Status"
		when 3 
			return "Retweet"
		when 2
			return "Mention"
		# when "spam"
			# return "Spam"
		when 4
			return "Private Message"
		# when "mention reply"
			# return "Reply"
		else
			return "Mention"
		end
	end

	def eng_style(engagement_type)
		case engagement_type
		when 3 
			return "btn-success"
		when 2
			return "btn-info"
		# when "spam"
			# return "btn-warning"
		when 4
			return "btn-inverse"
		end
	end

	def interaction_icon(interaction_type)
		case interaction_type
		when 2
			return "icon-comment"
		when 3
			return "icon-retweet"
		when 4
			return "icon-envelope"
		end
	end
end
