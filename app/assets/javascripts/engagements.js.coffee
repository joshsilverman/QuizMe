# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	$('.btn.btn-success.correct').click -> 
		#getResponse('correct')
		getResponse('correct', asker_id, $(this).attr('e_id'), true)
	$('.btn.btn-success.first').click -> 
		#getResponse('fast')
	$('.btn.btn-danger.incorrect').click -> 
		#getResponse('incorrect')
		getResponse('incorrect', asker_id, $(this).attr('e_id'), false)
	$('.btn.btn-danger.close').click -> 
		#getResponse('close')
	$('.btn.btn-warning.skip').click -> 
		getResponse('skip', asker_id, $(this).attr('e_id'), null)

	getResponse = (response_type, asker_id, engagement_id, correct) ->
		response = {}
		response['response_type'] = response_type
		response['asker_id'] = asker_id
		response['engagement_id'] = engagement_id
		response['correct'] = correct
		$.ajax '/engagements/response',
			type: 'POST'
			dataType: 'html'
			data: response
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) =>
				console.log "Success"
				console.log data

	updateEngagement = (options) ->
		$.ajax '/engagements/update',
			type: 'POST'
			dataType: 'html'
			data: mem
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) ->
				console.log "Success"
				console.log data