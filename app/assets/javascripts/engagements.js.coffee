# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	$('.btn.btn-success.correct').on 'click', ()-> 
		#getResponse('correct')
		getResponse('correct', asker_id, $(this).attr('p_id'), true)

	$('.btn.btn-success.first').click -> 
		#getResponse('fast')

	$('.btn.btn-danger.incorrect').click -> 
		getResponse('incorrect', asker_id, $(this).attr('p_id'), false)

	$('.btn.btn-danger.close').click -> 
		getResponse('close')

	$('.btn.btn-warning.skip').click -> 
		getResponse('skip', asker_id, $(this).attr('p_id'), null)

	$('.btn.btn-warning.retweet').click -> 
		getResponse('retweet', asker_id, $(this).attr('p_id'), null)

	getResponse = (response_type, asker_id, post_id, correct) ->
		responseHash = {}
		responseHash['response_type'] = response_type
		responseHash['asker_id'] = asker_id
		responseHash['post_id'] = post_id
		responseHash['correct'] = correct
		console.log responseHash
		$.ajax '/posts/respond_to_post',
			type: 'POST'
			data: responseHash
			beforeSend: ()->
				console.log "beforeSend"
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) =>
				console.log "Success"
				console.log data

	updatePost = (options) ->
		mem = []
		$.ajax '/posts/update',
			type: 'POST'
			dataType: 'html'
			data: mem
			beforeSend: ()->
				console.log 'weird shit'
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) ->
				console.log "Success"
				console.log data