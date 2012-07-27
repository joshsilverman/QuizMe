# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	# TODO => click on question area adds mandatory text + selects span when signed in
	$('.btn.btn-success').click -> 
		respond(true, $(this).attr('qid'))
	$('.btn.btn-danger').click -> 
		respond(false, $(this).attr('qid'))
	$("#question_dummy").on "keyup", (e) => 
		$("#character_count").text(140 - ($("#question").text().length + $("#link").text().length + 2))
	$("#question_dummy").on "click", => select_question_span()
	$("#add_answer").on "click", => 
		count = $(".answer").length
		return if count > 3
		$("#ianswer1").clone().attr("id", "ianswer#{count}").attr("name", "ianswer#{count}").val("").appendTo("#answers").focus()
	$("#sign_in").on "click", => select_question_span()

	$(".submit_container .btn").on "click", (e) => 
		# TODO: form validations
		e.preventDefault()
		data =
			"question" : $("#question").text()
			"topic_tag" : $("#topic_tag").val()
			"account_id" : $("#account_id").val()
			"canswer" : $("#canswer").val()
			"ianswer1" : $("#ianswer1").val()
			# "ianswer2" : $("")
			# "ianswer3" : $("")
		$.ajax
			url: "/questions/save_question_and_answers",
			type: "POST",
			data: data,
			success: => console.log "yo"

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