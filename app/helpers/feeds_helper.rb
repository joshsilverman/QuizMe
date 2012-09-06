module FeedsHelper
	def eng_name(engagement_type)
		case engagement_type
		when "share" 
			return "Retweet"
		when "mention"
			return "Mention"
		when "spam"
			return "Spam"
		when "pm"
			return "Private Message"
		when "mention reply"
			return "Reply"
		else
			return "Mention"
		end
	end

	def eng_style(engagement_type)
		case engagement_type
		when "share" 
			return "btn-success"
		when "mention"
			return "btn-info"
		when "spam"
			return "btn-warning"
		when "pm"
			return "btn-inverse"
		end
	end
end
