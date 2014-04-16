module FeedsHelper
	def silhouette_style
		if @asker.try :styles
			bg_color = @asker.styles["bg_color"]
			silhouette_color = @asker.styles["silhouette_color"]
		end

		bg_color ||= '#202734'
		silhouette_color ||= '#292935'

		"background: #{bg_color}; fill: #{silhouette_color};"
	end

	def embed_silhouette_image
		if @asker.try :styles
			silhouette_image = @asker.styles["silhouette_image"]
		end

		silhouette_image ||= 'bg_images/nature.svg'

	  file = File.open("app/assets/images/#{silhouette_image}", "rb")

	  raw file.read
	end

	def quest_image_tag
		if @asker.try :styles
			quest_image_url = @asker.styles['quest_image']
		end

		quest_image_url ||= 'quests/scholar.png'

		image_tag quest_image_url
	end

	def main_view_styles
		if @asker.try :styles
			bg_color = @asker.styles["bg_color"]
		end

		bg_color ||= '#202734'

		"background: #{bg_color};"
	end

	def header_styles
		if @asker.try :styles
			silhouette_color = @asker.styles["silhouette_color"] || '#292935'
		end
		
		silhouette_color ||= '#292935'

		header_bg_color = darken_color silhouette_color, 1

		"background: #{header_bg_color};"
	end

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
		return '', nil if text.nil?
		
		if text.include? "Learn more at"
			resource_link = text.match(/http:\/\/wisr.co\/[^ ]*/).to_s
			text.gsub! resource_link, ""
		else
			text.gsub! text.match(/http:\/\/wisr.co\/[^ ]*/).to_s, ""
		end

		return text, resource_link
	end

private

	def darken_color(hex_color, amount=0.1)
	  hex_color = hex_color.gsub('#','')
	  rgb = hex_color.scan(/../).map {|color| color.hex}

	  rgb[0] = (rgb[0].to_i * amount).round
	  rgb[1] = (rgb[1].to_i * amount).round
	  rgb[2] = (rgb[2].to_i * amount).round

	  "#%02x%02x%02x" % rgb
	end
end
