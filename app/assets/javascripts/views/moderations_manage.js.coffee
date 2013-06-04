class ModerationsManage
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

		$.post '/moderations', params, ->
			elem.closest('.conversation').addClass('moderated')

		elem.closest(".conversation").addClass "dim"
		window.moderations_manage.hotkeys.prev()

$ ->
	if $('.moderations_manage').length > 0
		window.moderations_manage = new ModerationsManage
