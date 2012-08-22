# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	$('.btn.btn-success.correct').click -> 
		#getResponse('correct')
		getResponse('correct', asker_id, $(this).attr('p_id'), true)
	$('.btn.btn-success.first').click -> 
		#getResponse('fast')
	$('.btn.btn-danger.incorrect').click -> 
		#getResponse('incorrect')
		getResponse('incorrect', asker_id, $(this).attr('p_id'), false)
	$('.btn.btn-danger.close').click -> 
		#getResponse('close')
	$('.btn.btn-warning.skip').click -> 
		getResponse('skip', asker_id, $(this).attr('p_id'), null)
	$('.btn.btn-warning.retweet').click -> 
		getResponse('retweet', asker_id, $(this).attr('p_id'), null)

	getResponse = (response_type, asker_id, post_id, correct) ->
		response = {}
		response['response_type'] = response_type
		response['asker_id'] = asker_id
		response['post_id'] = post_id
		response['correct'] = correct
		console.log response
		$.ajax '/posts/response',
			type: 'POST'
			dataType: 'html'
			data: response
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) =>
				console.log "Success"
				console.log data

	updatePost = (options) ->
		$.ajax '/posts/update',
			type: 'POST'
			dataType: 'html'
			data: mem
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) ->
				console.log "Success"
				console.log data