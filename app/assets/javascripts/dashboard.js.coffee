class Dashboard
	display_data: null
	graph_data: null
	askers: null
	active: []
	dau_mau: null
	paulgraham: null

	constructor: -> 
		@askers = $.parseJSON($("#askers").val())
		@display_data = $.parseJSON($("#display_data").val())
		@graph_data = $.parseJSON($("#graph_data").val())
		@paulgraham = $.parseJSON($("#paulgraham").val())
		@dau_mau = $.parseJSON($("#dau_mau").val())
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
		# console.log @active
		@draw_graphs()
		@draw_dau_mau()
		@draw_paulgraham()
		@update_metrics()
	update_metrics: =>
		askers = []
		display_hash = 
			followers: today: 0, total: 0
			active_users: today: [], total: []
			questions_answered: today: 0, total: 0
			click_throughs: today: 0, total: 0
			mentions: today: 0, total: 0
			retweets: today: 0, total: 0
		if "0" in @active then askers.push(0) else askers.push(asker_id) for asker_id in @active
		for asker_id in askers
			for key of display_hash
				if key == "active_users"
					display_hash[key]["today"] = display_hash[key]["today"].concat(@display_data[asker_id][key]["today"])
					display_hash[key]["total"] = display_hash[key]["total"].concat(@display_data[asker_id][key]["total"])
				else
					display_hash[key]["today"] += @display_data[asker_id][key]["today"]
					display_hash[key]["total"] += @display_data[asker_id][key]["total"]
		for key, value of display_hash
			if key == "active_users"
				$("##{key}_stats .new .number").text(value.today.unique().length)
				$("##{key}_stats .total .number").text(value.total.unique().length)
			else
				$("##{key}_stats .new .number").text(value.today)
				$("##{key}_stats .total .number").text(value.total)
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
				# console.log date#, asker_data if attribute_name == "active_user_ids"
				date_array = date.split("-")
				row = ["#{date_array[1]}/#{date_array[2]}"]
				row.push(0) for i in @active
				if "0" in @active
					if attribute_name == "active_user_ids" then total = [] else total = 0
					for asker_id, data of @askers
						if asker_data[asker_id] == undefined or asker_data[asker_id] == null
							row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = 0 if asker_id in @active
						else
							if attribute_name == "active_user_ids" 
								row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id].unique().length if asker_id in @active
								total = total.concat(asker_data[asker_id])
							else
								row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id] if asker_id in @active
								total += asker_data[asker_id]
					if attribute_name == "active_user_ids"
						row[title_row.indexOf("Total")] = total.unique().length
					else 
						row[title_row.indexOf("Total")] = total
					data_array.push(row)
				else
					for asker_id in @active
						if asker_data[asker_id] == undefined or asker_data[asker_id] == null
							row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = 0
						else
							if attribute_name == "active_user_ids" 
								console.log asker_data[asker_id]
								row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id].unique().length
							else
								row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id]			
					data_array.push(row)
			graph_data = google.visualization.arrayToDataTable(data_array)
			chart = new google.visualization.LineChart(document.getElementById("#{attribute_name}_graph"))
			chart.draw graph_data, options

	draw_paulgraham: =>
		title_row = ["Date", "Total"]
		data_array = [['Date', 'Min', 'Max', "Over", "Wayover", 'Total']]
		$.each @paulgraham, (k,v) -> 
			v = .2 if v > .2
			data_array.push [k, .05, .05, .05, .05, v - .2]

		graph_data = google.visualization.arrayToDataTable(data_array)
		chart = new google.visualization.AreaChart(document.getElementById("paulgraham_graph"))
		chart.draw graph_data, pg_options
	draw_dau_mau: =>
		data_array = [["Date", "Ratio"]]
		$.each @dau_mau, (k,v) -> 
			date_array = k.split("-")
			data_array.push(["#{date_array[1]}/#{date_array[2]}", v])
		graph_data = google.visualization.arrayToDataTable(data_array)
		chart = new google.visualization.LineChart(document.getElementById("dau_mau_graph"))
		chart.draw graph_data, options		


$ -> window.dashboard = new Dashboard if $("#dashboard").length > 0

pg_options = 
	width: 430
	height: 225
	legend: "none"
	pointSize: 0
	lineWidth: 3
	chartArea:  
		width: 430
		left: 30
		height: 175
	hAxis:
		textStyle: 
			fontSize: 9
	series: [{lineWidth:0},{lineWidth:0},{lineWidth:0},{lineWidth:0},{areaOpacity: 0, pointSize: 6}]
	isStacked: true
	vAxis: {maxValue: 0.2}
	colors: ['orange', 'green', 'orange', 'orange', "#6C69D1"]

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
Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output