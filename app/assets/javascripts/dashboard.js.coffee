class Dashboard
	display_data: null
	graph_data: null
	askers: null
	active: []
	constructor: -> 
		@askers = $.parseJSON($("#askers").val())
		@display_data = $.parseJSON($("#display_data").val())
		@graph_data = $.parseJSON($("#graph_data").val())
		@active.push("0")
		$(".select_option").on "change", (e) => 
			if $(e.target).attr("value") == "0" and $(e.target).is(":checked") 
				@active.splice(0, 0, "0")
			else
				if $(e.target).is(":checked") 
					@active.push($(e.target).attr "value") 
				else 
					@active.remove($(e.target).attr "value")
			@update_dashboard()
		@update_dashboard()
	update_dashboard: =>
		@draw_graphs()
		@update_metrics()
	update_metrics: =>
		# console.log @display_data
	draw_graphs: =>
		colors = []
		colors.push(line_colors[asker_id]) for asker_id in @active
		options.colors = colors
		title_row = ["Date"]
		accounts = []
		accounts.push(asker_id) for asker_id, data of @askers
		for account_id in @active
			if account_id == "0" then title_row.push("Total") else title_row.push(@askers[account_id][0].twi_screen_name) 
		for attribute_name, attribute_data of @graph_data
			data_array = [title_row]
			for date, asker_data of attribute_data
				date_array = date.split("-")
				row = ["#{date_array[1]}/#{date_array[2]}"]
				row.push(0) for i in @active
				if "0" in @active
					total = 0
					for asker_id, data of @askers
						if asker_data[asker_id] == undefined or asker_data[asker_id] == null
							row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = 0 if asker_id in @active
						else
							row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id] if asker_id in @active
							total += asker_data[asker_id]
					row[title_row.indexOf("Total")] = total
					data_array.push(row)
				else
					for asker_id in @active
						if asker_data[asker_id] == undefined or asker_data[asker_id] == null
							row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = 0
						else
							row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id]
					data_array.push(row)
			graph_data = google.visualization.arrayToDataTable(data_array)
			chart = new google.visualization.LineChart(document.getElementById("#{attribute_name}_graph"))
			chart.draw graph_data, options

$ -> window.dashboard = new Dashboard if $("#dashboard").length > 0

options = 
	width: 430
	height: 225
	legend: "none"
	pointSize: 6
	lineWidth: 3
	chartArea:  
		width: 430
		left: 30
		height: 175
	hAxis:
		textStyle: 
			fontSize: 9

line_colors = 
	0: "#6C69D1"
	2: "#69D175"
	19: "#D1B269"
	31: "#D169C1"
	66: "#D1696A"

titles = 
	followers: "Followers"
	active_users: "Active Users"
	questions_answered: "Questions Answered"
	click_throughs: "Click Throughs"
	retweets: "Retweets"
	mentions: "Mentions"

Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1