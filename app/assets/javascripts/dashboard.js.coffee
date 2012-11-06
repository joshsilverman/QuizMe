class Dashboard
	display_data: null
	graph_data: null
	askers: null
	active: []
	dau_mau: null
	paulgraham: null
	handle_activity: null

	constructor: -> 
		@askers = $.parseJSON($("#askers").val())
		@display_data = $.parseJSON($("#display_data").val())
		@graph_data = $.parseJSON($("#graph_data").val())

		@paulgraham = $.parseJSON($("#paulgraham").val())
		@dau_mau = $.parseJSON($("#dau_mau").val())
		@daus = $.parseJSON($("#daus").val())

		@econ_engine = $.parseJSON($("#econ_engine").val())
		@handle_activity = $.parseJSON($("#handle_activity").val())

		@asker_ids = $.parseJSON($("#asker_ids").val())

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

		@draw_paulgraham()
		@draw_dau_mau()
		@draw_daus()
		@draw_econ_engine()
		@draw_handle_activity()

		@update_metrics()
	update_metrics: =>
		askers = []
		display_hash = 
			followers: today: 0, total: 0
			active_users: today: [], total: []
			questions_answered: today: 0, total: []
			click_throughs: today: 0, total: 0
			mentions: today: 0, total: 0
			retweets: today: 0, total: 0
		if "0" in @active then askers.push(0) else askers.push(asker_id) for asker_id in @active
		for asker_id in askers
			for key of display_hash
				if key == "active_users"
					display_hash[key]["today"] = display_hash[key]["today"].concat(@display_data[asker_id][key]["today"])
					display_hash[key]["total"] = display_hash[key]["total"].concat(@display_data[asker_id][key]["total"])
				else if key == "questions_answered"
					display_hash[key]["today"] += @display_data[asker_id][key]["today"]
					display_hash[key]["total"] = display_hash[key]["total"].concat(@display_data[asker_id][key]["total"])				
				else
					display_hash[key]["today"] += @display_data[asker_id][key]["today"]
					display_hash[key]["total"] += @display_data[asker_id][key]["total"]
		for key, value of display_hash
			if key == "active_users"
				$("##{key}_stats .new .number").text(value.today.unique().length)
				$("##{key}_stats .total .number").text(value.total.unique().length)
			else if key == "questions_answered"
				$("##{key}_stats .new .number").text(value.today)
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
				else
					for asker_id in @active
						if asker_data[asker_id] == undefined or asker_data[asker_id] == null
							row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = 0
						else
							if attribute_name == "active_user_ids" 
								row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id].unique().length
							else
								row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id]			
				data_array.push(row)
			graph_data = google.visualization.arrayToDataTable(data_array)
			chart = new google.visualization.LineChart(document.getElementById("#{attribute_name}_graph"))
			chart.draw graph_data, options

	draw_paulgraham: =>
		data_array = [['Date', 'Min', 'Max', "Over", 'Total', '7 Day Avg']]
		$.each @paulgraham, (k,v) -> 
			v['avg'] = .2 if v['avg'] > .2
			data_array.push [k, .05, .05, .05, v['raw'], v['avg']]
		graph_data = google.visualization.arrayToDataTable(data_array)
		chart = new google.visualization.ComboChart(document.getElementById("paulgraham_graph"))
		chart.draw graph_data, pg_options

	draw_dau_mau: =>
		data_array = [["Date", "Ratio"]]
		$.each @dau_mau, (k,v) -> 
			date_array = k.split("-")
			data_array.push(["#{date_array[1]}/#{date_array[2]}", v])
		graph_data = google.visualization.arrayToDataTable(data_array)
		chart = new google.visualization.LineChart(document.getElementById("dau_mau_graph"))
		chart.draw graph_data, dau_mau_options		

	draw_daus: =>
		data_array = [["Date", "DAU"]]
		$.each @daus, (k,v) -> 
			date_array = k.split("-")
			data_array.push(["#{date_array[1]}/#{date_array[2]}", v])
		graph_data = google.visualization.arrayToDataTable(data_array)
		chart = new google.visualization.LineChart(document.getElementById("daus_graph"))
		chart.draw graph_data, dau_mau_options	

	draw_econ_engine: =>
		graph_data = google.visualization.arrayToDataTable(@econ_engine)
		chart = new google.visualization.AreaChart(document.getElementById("econ_engine_graph"))
		chart.draw graph_data, econ_engine_options

	draw_handle_activity: =>
		graph_data = google.visualization.arrayToDataTable(@handle_activity)
		chart = new google.visualization.ColumnChart(document.getElementById("handle_activity_graph"))
		chart.draw graph_data, handle_activity_options	

$ -> 
	window.dashboard = new Dashboard if $(".dashboard").length > 0
	$('#tabs a').click (e) ->
	  e.preventDefault()
	  $(this).tab('show')

pg_options = 
	width: 425
	height: 275
	legend: "none"
	chartArea:  
		width: 420
		left: 30
		height: 225
	hAxis:
		textStyle: 
			fontSize: 9
	vAxis:
		viewWindowMode: 'explicit'
		viewWindow:
			max: 0.1501
	series: [
		{type:'area', lineWidth:0},
		{type:'area', lineWidth:0},
		{type:'area', lineWidth:0},
		{areaOpacity: 0, lineWidth: 0, color:'#6C69D1', pointSize:3},
		{areaOpacity: 0, pointSize: 0, color:'#6C69D1', curveType: "function"}]
	isStacked: true
	colors: ['orange', 'green', 'orange', "#6C69D1"]

dau_mau_options = 
	width: 425
	height: 275
	legend: "none"
	pointSize: 6
	lineWidth: 3
	chartArea:  
		width: 420
		left: 30
		height: 225
	vAxis:
		viewWindowMode: 'explicit'
		viewWindow:
			min: 0
	hAxis:
		textStyle: 
			fontSize: 9
	colors: ["#6C69D1"]

econ_engine_options =
	isStacked: true
	width: 425
	height: 275
	pointSize: 0
	lineWidth: 1
	chartArea:  
		width: 420
		left: 30
		height: 225
	hAxis:
		textStyle: 
			fontSize: 9
	vAxis:
		minorGridlines:
			count: 3
			color: "#eee"

handle_activity_options = 
	width: 1100
	height: 550
	legend: "none"
	pointSize: 6
	lineWidth: 3
	isStacked: true
	title: "Total Social Interactions this Week"
	chartArea:  
		width: 1100
		left: 50
		height: 450
	hAxis:
		textStyle: 
			fontSize: 9
		slantedText: true
	vAxis:
		viewWindowMode: 'explicit'
		viewWindow:
			min: 0

options = 
	width: 425
	height: 275
	legend: "none"
	pointSize: 6
	lineWidth: 3
	chartArea:  
		width: 420
		left: 30
		height: 225
	hAxis:
		textStyle: 
			fontSize: 9
	vAxis:
		viewWindowMode: 'explicit'
		viewWindow:
			min: 0

line_colors = 
	0: "#6C69D1"
	2: "#69D175"
	19: "#D1B269"
	31: "#D169C1"
	66: "#D1696A"

Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1
Array::unique = ->
	output = {}
	output[@[key]] = @[key] for key in [0...@length]
	value for key, value of output
