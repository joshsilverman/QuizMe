class FeedsModeratorManage
	constructor: ->
		$(".quick-reply").on "click", @quick_reply

		# toggle open post
		$('.conversation').first().addClass 'active'
		$(".conversation").on "click", ->
			$('.conversation').removeClass 'active'
			$(this).addClass 'active'

		@hotkeys = new Hotkeys false

	quick_reply: ->
		elem = $(this)
		params =
			type_id: elem.data 'type_id'
			post_id: elem.closest(".post").attr 'post_id'

		$.post '/moderator_response', params#, ->

		elem.closest(".conversation").addClass "dim"
		window.feeds_moderator_manage.hotkeys.prev()

$ ->
	if $('.feeds_moderator_manage').length > 0
		window.feeds_moderator_manage = new FeedsModeratorManage
