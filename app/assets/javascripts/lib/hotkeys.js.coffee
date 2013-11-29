class window.Hotkeys
	constructor: (enable_hotkeys) ->
		if enable_hotkeys
			$(window).keypress (e) =>
				return if e.target and (e.target.tagName == "TEXTAREA" or e.target.tagName == "INPUT")
				active_post = @_active_post()
				# puts e.keyCode
				switch e.keyCode
					when 106 then @prev()
					when 107 then @next()
					when 111 then @open(e)

					when 32 then @accept_autocorrect(e, active_post)
					when 110 then active_post.quick_reply false if active_post #no
					when 116 then active_post.quick_reply false, true if active_post #yes
					when 121 then active_post.quick_reply true if active_post #yes

					when 102 then $("#best_in_place_post_#{active_post.id}_spam").trigger('click') if active_post
					when 104 then @toggle_hide active_post
					when 114 then active_post.retweet() if active_post

					when 113 then window.feed.post_question(active_post.active_record.text, active_post.id)
					when 115 then active_post.element.find('.scripts .dropdown-toggle').dropdown('toggle')

					when 101 then e.preventDefault(); @toggle_email_panel()
					when 98 then @hide_panel()

	_before_toggle_panel: ->
		$('.active .sub').hide()
		$('.active .dropdown-menu').parent().removeClass('open')
		$('.active .actions').css overflow: 'hidden'
		$('.active .actions .container').addClass "more", 400, -> $(".active form input[type='text']").first().focus()

	hide_panel: =>
		$('.active .actions .container').removeClass "more", 400, ->
			$('.active .sub').hide()
			$('.active .actions').css overflow: 'inherit'

	toggle_question_feedback_panel: ->
		@_before_toggle_panel()
		$('.active .question_feedback_actions').show()

	toggle_email_panel: ->
		@_before_toggle_panel()
		$('.active .new-email').show()
		$('.new-email form input').focus()
		$('.new-email form').unbind 'ajax:complete'
		$('.active .new-email form').on 'ajax:complete', -> 
			$(this).html("Successfully update user email address!").addClass("alert alert-success")			

	accept_autocorrect: (e, active_post) ->
		e.preventDefault()
		if active_post
			autocorrect = active_post.active_record.autocorrect
			return if autocorrect == null

			active_post.quick_reply autocorrect

	toggle_hide: (post_obj) ->
		$("#best_in_place_post_#{post_obj.id}_requires_action").trigger('click') if post_obj

	open: (e) ->
		post_obj = @_active_post()

		# mimic event in calling expand
		e.preventDefault()
		post = $('.conversation.active .post')
		post_obj.expand({target: post}) if post_obj

	prev: ->
		current_conv = $('.conversation.active')
		prev_conv = current_conv.next('.conversation') #confusing because next in time is reverse in sequence
		prev_conv = $('#posts .conversation').first() if prev_conv.length == 0

		current_conv.removeClass 'active'
		$('.actions .container').removeClass "more"
		prev_conv.addClass 'active'
		@_isScrolledIntoView prev_conv

	next: ->
		current_conv = $('.conversation.active')
		next_conv = current_conv.prev('.conversation') #confusing because next in time is reverse in sequence
		next_conv = $('#posts .conversation').last() if next_conv.length == 0

		current_conv.removeClass 'active'
		$('.actions .container').removeClass "more"
		next_conv.addClass 'active'
		@_isScrolledIntoView next_conv

	_isScrolledIntoView: (elem) ->
		docViewTop = $(window).scrollTop()
		docViewBottom = docViewTop + $(window).height()

		elemTop = $(elem).offset().top
		elemBottom = elemTop + $(elem).height()

		visible = ((elemBottom >= docViewTop) && (elemTop <= docViewBottom) && (elemBottom <= docViewBottom) &&  (elemTop >= docViewTop))
		unless visible
			$('html, body').animate({
				scrollTop: elem.offset().top - 150
			}, 1);

	_active_post: (e) ->
		post = $('.conversation.active .post')
		return if post.length == 0

		post_id = post.attr "post_id"
		post_obj = null
		$.each feed.posts, (i, p) -> post_obj = p if p.id == post_id
		post_obj