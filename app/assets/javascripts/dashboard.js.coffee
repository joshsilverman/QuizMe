class Dashboard
	constructor: -> @draw_graph(attribute_name, data) for attribute_name, data of $.parseJSON($("#graph_data").val())
	draw_graph: (attribute_name, data) =>
		graph_data = new google.visualization.DataTable()
		graph_data.addColumn "string", "Date"
		graph_data.addColumn "number", titles[attribute_name]
		graph_data.addRow [day[0], day[1]] for day in data
		chart = new google.visualization.LineChart(document.getElementById("#{attribute_name}_graph"))
		chart.draw graph_data, options

$ -> window.dashboard = new Dashboard if $("#dashboard").length > 0

options = 
	width: 396
	height: 225
	legend: "none"
	chartArea:  
		width: 355
		left: 30
		height: 175

titles = 
	followers: "Followers"
	active_users: "Active Users"
	questions_answered: "Questions Answered"
	click_throughs: "Click Throughs"
	retweets: "Retweets"
	mentions: "Mentions"