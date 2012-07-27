# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	$('.btn.btn-success').click -> 
		respond(true, $(this).attr('qid'))
	$('.btn.btn-danger').click -> 
		respond(false, $(this).attr('qid'))

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