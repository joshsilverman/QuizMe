# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	$('.btn.btn-success').click -> 
		respond(true, $(this).attr('qid'))
	$('.btn.btn-danger').click -> 
		respond(false, $(this).attr('qid'))
	$("#question").on "keyup", (e) => 
		$("#character_count").text(140 - ($("#tweet").text().length + $("#link").text().length + 2))
	$("#add_answer").on "click", => 
		count = $(".answer").length
		return if count > 3
		$("#ianswer1").clone().attr("id", "ianswer#{count}").attr("name", "ianswer#{count}").appendTo("#answers")
	$("#sign_in").on "click", =>
		$("#link, #tweet").show()
		selection = window.getSelection()
		range = document.createRange()
		range.selectNodeContents(document.getElementById("tweet"))
		selection.removeAllRanges()
		selection.addRange(range)	
		$("#character_count").text(140 - ($("#tweet").text().length + $("#link").text().length + 2))
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