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
		count = 140 - ($("#question").text().length + $("#link").text().length + 2)
		if count < 0
			$("#character_count").css("color", "red")
			$("#question_dummy").css("border-color", "red")
		else
			$("#character_count").css("color", "black")
			$("#question_dummy").css("border-color", "rgba(175, 195, 211, 0.941)")
		$("#character_count").text(String(count))
	$("#question_dummy").on "click", => select_question_span()
	$("#add_answer").on "click", => 
		count = $(".answer").length
		return if count > 3
		$("#ianswer1").clone().attr("id", "ianswer#{count}").attr("name", "ianswer#{count}").val("").appendTo("#answers").focus()
	$(".submit_container .btn").on "click", (e) => 
		e.preventDefault()
		alert "Question is too long!" if $("#character_count").text() < 0
		# data =
		# 	"question" : $("#question").text()
		# 	"topic_tag" : $("#topic_tag").val()
		# 	"account_id" : $("#account_id").val()
		# 	"canswer" : $("#canswer").val()
		# 	"ianswer1" : $("#ianswer1").val()
		# 	"ianswer2" : $("#ianswer2").val()
		# 	"ianswer3" : $("#ianswer3").val()
		# $.ajax
		# 	url: "/questions/save_question_and_answers",
		# 	type: "POST",
		# 	data: data,
		# 	success: (e) => console.log e

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