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

	def time_formatter(date)
		if (Date.today - date).to_i > 0
			time = date.strftime("%m/%d")
			time.gsub! "/0", "/"
			time.slice!(0) if time[0] == "0"
		else 
			time = time_ago_in_words(date)
			time.gsub!("about ", "")
			time.gsub!(" hours", "h")
			time.gsub!(" minutes", "m")
			time.gsub!(" seconds", "s")
		end
		return time
	end
end
