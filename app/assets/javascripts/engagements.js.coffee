# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	$('.btn.btn-success.correct').click -> 
		getResponse('correct')
	$('.btn.btn-success.first').click -> 
		getResponse('fast')
	$('.btn.btn-danger.incorrect').click -> 
		getResponse('incorrect')
	$('.btn.btn-danger.close').click -> 
		getResponse('close')
	$('.btn.btn-warning.skip').click -> 
		updateEngagement({''})

	getResponse = (response) ->
		response = {}
		response['type'] = response
		$.ajax '/mentions/update',
			type: 'POST'
			dataType: 'html'
			data: mem
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) ->
				console.log "Success"
				console.log data