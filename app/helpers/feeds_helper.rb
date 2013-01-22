module FeedsHelper
	def eng_name(engagement_type)
		case engagement_type
		when 1 
			return "Status"
		when 3 
			return "Retweet"
		when 2
			return "Mention"
		when 4
			return "Private Message"
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
		when 4
			return "btn-inverse"
		end
	end

	def interaction_icon(interaction_type)
		case interaction_type
		when 2
			return "" #"icon-comment"
		when 3
			return "icon-retweet"
		when 4
			return "icon-envelope"
		end
	end

	def time_formatter(date)
		if date.to_date == Date.today
			time = time_ago_in_words(date)
			time.gsub!("less than a minute", "1m")
			time.gsub!("about ", "")
			time.gsub!(" hours", "h")
			time.gsub!(" hour", "h")
			time.gsub!(" minutes", "m")
			time.gsub!(" minute", "m")
			time.gsub!(" seconds", "s")
			time.gsub!(" second", "s")
		else 
			time = date.strftime("%m/%d")
			time.gsub! "/0", "/"
			time.slice!(0) if time[0] == "0"
		end
		return time
	end	

	def format_response(text, resource_link = nil)
		if text.include? "Learn more at"
			resource_link = text.match(/http:\/\/wisr.co\/[^ ]*/).to_s
			text.gsub! resource_link, ""
		end
		return text, resource_link
	end
end
