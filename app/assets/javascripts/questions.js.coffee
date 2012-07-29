# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	$('.btn.btn-success').click -> respond(true, $(this).attr('qid'))
	$('.btn.btn-danger').click -> respond(false, $(this).attr('qid'))
	$("#question_dummy").on "keyup", (e) => update_character_count()
	$("#question_dummy").on "click", => if $("#name").val() then select_question_span()	else alert "Please sign in first!"
	$(".answer").on "click", => alert "Please sign in first!" unless $("#name").val()
	$("#add_answer").on "click", => add_answer()
	$(".submit_container .btn").on "click", (e) => 
		e.preventDefault()
		submit()

	add_answer = ->
		if $("#name").val()
			count = $(".answer").length
			return if count > 3
			$("#ianswer1").clone().attr("id", "ianswer#{count}").attr("name", "ianswer#{count}").val("").appendTo("#answers").focus()
			$("#add_answer").hide() if count == 3
		else
			alert "Please sign in first!"

	update_character_count = () ->
		count = 140 - ($("#question").text().length + $("#link").text().length + 2)
		if count < 0
			$("#character_count").css("color", "red")
			$("#question_dummy").css("border-color", "red")
		else
			$("#character_count").css("color", "black")
			$("#question_dummy").css("border-color", "rgba(175, 195, 211, 0.941)")
		$("#character_count").text(String(count))

	select_question_span = ->
		$("#link, #question, #account").show()
		$("#question").text("Your question") unless $("#question").text()
		selection = window.getSelection()
		range = document.createRange()
		range.selectNodeContents(document.getElementById("question"))
		selection.removeAllRanges()
		selection.addRange(range)	
		$("#character_count").text(140 - ($("#question").text().length + $("#link").text().length + 2))		

	submit = ->
		if validate_form()
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

	validate_form = ->
		if $("#character_count").text() < 0
			alert "Your question is too long!" 
			return false
		else if $("#question").text().length == 0 or $("#question").text() == "Your question"
			alert "Please enter a question!"
			return false
		else if $("#canswer").val().length == 0 or $("#ianswer1").val().length == 0
			alert "Please enter at least one correct and incorrect answer!"
			return false
		else
			return true		

	respond = (accepted, id) ->
		q = {}
		q['question_id'] = parseInt id
		q['accepted'] = accepted
		$.ajax '/moderate/update',
			type: 'POST'
			dataType: 'html'
			data: q
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) ->
				console.log "Success"
				console.log data