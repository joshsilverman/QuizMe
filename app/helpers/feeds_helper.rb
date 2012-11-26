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

	def time_formatter(date)
		if date.to_date == Date.today
			time = time_ago_in_words(date)
			time.gsub!("about ", "")
			time.gsub!(" hours", "h")
			time.gsub!(" minutes", "m")
			time.gsub!(" seconds", "s")
			time.gsub!("less than a minute", "1m")
		else 
			time = date.strftime("%m/%d")
			time.gsub! "/0", "/"
			time.slice!(0) if time[0] == "0"
		end
		return time
	end	

	def format_response(text)
		if text.include? "Find the answer at"
			links = text.scan /http:\/\/wisr.co\/[^ ]*/
			text = text.gsub links[0], ""
			text = text.gsub links[1], ""
			link = links[1]
			# puts text.sub /http:\/\/wisr.co\/[^ ]*/, ""
			# puts text.split("Find the answer at")
		else
			text = text.split("http")[0]
			link = nil
		end
		return text, link
	end

end
