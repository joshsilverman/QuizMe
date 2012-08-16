# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/


$ ->
	drawCharts = ->
		drawQuestionsAnswered()
		drawDailyActiveUsers()
		drawRetweets()
		drawRetentionTable('weekly-retention-twitter-graph',
											 'Weekly Retention: Twitter',
											 $.parseJSON($("#weekly_twi_ret").attr("value")))
		drawRetentionTable('weekly-retention-studyegg-graph',
											 'Weekly Retention: StudyEgg',
											 $.parseJSON($("#weekly_int_ret").attr("value")))
		drawRetentionTable('daily-retention-twitter-graph',
											 'Daily Retention: Twitter',
											 $.parseJSON($("#daily_twi_ret").attr("value")))
		drawRetentionTable('daily-retention-studyegg-graph',
											 'Daily Retention: StudyEgg',
											 $.parseJSON($("#daily_int_ret").attr("value")))

	drawQuestionsAnswered = ->
		data = new google.visualization.DataTable()
		data.addColumn "string", "Date"
		data.addColumn "number", "Twitter"
		data.addColumn "number", "QuizMe"
		data.addColumn "number", "Total"

		qa = $.parseJSON($("#qa").attr("value"))
		$.each qa, (date,qs)->
			data.addRow [date, qs[0], qs[1], qs[2]]

		options = 
			width: 370
			height: 260

		chart = new google.visualization.LineChart(document.getElementById("questions-answered-graph"))
		chart.draw data, options

	drawDailyActiveUsers = ->
		data = new google.visualization.DataTable()
		data.addColumn "string", "Date"
		data.addColumn "number", "Twitter"
		data.addColumn "number", "QuizMe"
		data.addColumn "number", "Total"
		dau = $.parseJSON($("#dau").attr("value"))
		$.each dau, (date,ds)->
			data.addRow [date, ds[0], ds[1], ds[2]]

		options = 
			width: 370
			height: 260

		chart = new google.visualization.LineChart(document.getElementById("daily-active-users-graph"))
		chart.draw data, options

	drawRetweets = ->
		data = new google.visualization.DataTable()
		data.addColumn "string", "Date"
		data.addColumn "number", "Twitter"

		rts = $.parseJSON($("#rts").attr("value"))
		$.each rts, (date,rt)->
			data.addRow [date, rt]

		options = 
			width: 370
			height: 260

		chart = new google.visualization.LineChart(document.getElementById("retweets-graph"))
		chart.draw data, options

	drawRetentionTable = (div, title, ret_json)->
		return if ret_json == null
		data = new google.visualization.DataTable()
		console.log ret_json
		max_count = 0
		ret_array = []
		$.each ret_json, (date, count)->
			ret_array.push([date,count])
			max_count = count['counts'].length if count['counts'].length > max_count
		console.log max_count
		data.addColumn "string", "date"
		data.addColumn "number", "0"
		
		for i in [1..max_count]
			data.addColumn "number", "#{i}"
		ret_array.sort()
		$.each ret_array, (i, item)->
			ary = ["#{item[0]}", item[1]['first']]
			$.each item[1]['counts'], (k, c)->
				console.log "#{k} pushing #{c}"
				ary.push c
			while ary.length < max_count+2
				ary.push null
			console.log ary
			data.addRow ary


		for i in [max_count-1..0]
			for j in [max_count-1..0]
				data.setCell(i, max_count+1-j, null, null, {'className':'blank-cell'}) if i>j
		options = 
			title: 'Test Title'

		table = new google.visualization.Table(document.getElementById("#{div}"))
		table.draw data, options

	drawRepsChart = ->
		data = new google.visualization.DataTable()
		data.addColumn "string", "Date"
		data.addColumn "number", "Items Studied"
		for date, reps of jQuery.parseJSON $("#reps_data").html()
			console.log date
			console.log reps
			data.addRow [date, reps]
		options =
			width: 450
			height: 300
			title: "Items Studied"
		chart = new google.visualization.LineChart(document.getElementById("reps_chart"))
		chart.draw data, options

	if $('.stats').length>0
		google.load "visualization", "1",
			packages: [ "corechart", "table" ],
			callback: drawCharts