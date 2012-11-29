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
			return "icon-comment"
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

	def format_response(text)
		if text.include? "Find the answer at" or text.include? "Find out why at"
			resource_link = text.match(/Find the answer at http:\/\/wisr.co\/[^ ]*/)
			if resource_link
				resource_link = resource_link.to_s.gsub("Find the answer at ", "")
			else
				resource_link = text.match(/Find out why at http:\/\/wisr.co\/[^ ]*/).gsub("Find out why at ", "")
			end
			text.scan(/http:\/\/wisr.co\/[^ ]*/).each { |link| text.gsub!(link, "") }
			text = text.gsub "Find the answer at", "Find the correct answer"
			text = text.gsub "Find out why at", "Find out why"
		else
			text = text.split("http")[0]
			resource_link = nil
		end
		return text, resource_link
	end
end
