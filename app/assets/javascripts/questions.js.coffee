# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	console.log $("#name").val()
	$('.btn.btn-success').click -> 
		respond(true, $(this).attr('qid'))
	$('.btn.btn-danger').click -> 
		respond(false, $(this).attr('qid'))
	$("#question_dummy").on "keyup", (e) => 
		count = 140 - ($("#question").text().length + $("#link").text().length + 2)
		if count < 0
			$("#character_count").css("color", "red")
			$("#question_dummy").css("border-color", "red")
		else
			$("#character_count").css("color", "black")
			$("#question_dummy").css("border-color", "rgba(175, 195, 211, 0.941)")
		$("#character_count").text(String(count))
	$("#question_dummy").on "click", => 
		if $("#name").val()
			select_question_span()
		else
			alert "Please sign in first!"
	$(".answer").on "click", => alert "Please sign in first!" unless $("#name").val()
	$("#add_answer").on "click", => 
		unless $("#name").val()
			alert "Please sign in first!"
			return
		count = $(".answer").length
		return if count > 3
		$("#ianswer1").clone().attr("id", "ianswer#{count}").attr("name", "ianswer#{count}").val("").appendTo("#answers").focus()
		$("#add_answer").hide() if count == 3
	$(".submit_container .btn").on "click", (e) => 
		console.log $("#ianswer1").val()
		e.preventDefault()
		if $("#character_count").text() < 0
			alert "Your question is too long!" 
		else if $("#question").text().length == 0 or $("#question").text() == "Your question"
			alert "Please enter a question!"
		else if $("#canswer").val().length == 0 or $("#ianswer1").val().length == 0
			alert "Please enter at least one correct and incorrect answer!"
		else
			data =
				"question" : $("#question").text()
				"topic_tag" : $("#topic_tag").val()
				"account_id" : $("#account_id").val()
				"canswer" : $("#canswer").val()
				"ianswer1" : $("#ianswer1").val()
				"ianswer2" : $("#ianswer2").val()
				"ianswer3" : $("#ianswer3").val()
			$.ajax
				url: "/questions/save_question_and_answers",
				type: "POST",
				data: data,
				success: (e) => document.location.reload(true)

	select_question_span = ->
		$("#link, #question, #account").show()
		selection = window.getSelection()
		range = document.createRange()
		range.selectNodeContents(document.getElementById("question"))
		selection.removeAllRanges()
		selection.addRange(range)	
		$("#character_count").text(140 - ($("#question").text().length + $("#link").text().length + 2))		

	respond = (accepted, id) ->
		q = {}
		q['question_id'] = parseInt id
		q['accepted'] = accepted
		console.log q
		$.ajax '/moderate/update',
			type: 'POST'
			dataType: 'html'
			data: q
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) ->
				console.log "Success"
				console.log data