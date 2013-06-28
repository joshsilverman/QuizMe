class ModerationsManage
	constructor: ->
		$(".quick-reply").on "click", @quick_reply

		# # toggle open post
		$('.conversation').first().addClass 'active'
		$(".conversation").on "click", ->
			$('.conversation').removeClass 'active'
			$(this).addClass 'active'

		@hotkeys = new Hotkeys false

	quick_reply: ->
		elem = $(this)
		conversation = elem.closest('.conversation')
		params =
			type_id: elem.data 'type_id'
			post_id: elem.closest(".post").attr 'post_id'

		$.post '/moderations', params, (e) ->
			conversation.addClass('moderated')
			# @notify()
			console.log e

		conversation.addClass "dim"
		window.moderations_manage.hotkeys.prev() if conversation.nextAll(".conversation").length < 1
	
	notify: (e) ->
		$.gritter.add
			title: "@#{e.data.screen_name}",
			text: "Thanks for following! I'll DM you a question shortly."
			image: $("img[title=#{e.data.screen_name}]").attr 'src'
			time:9000

		$.ajax '/experiments/trigger',
			type: 'post'
			data: {experiment: "New Landing Page"}		

$ ->
	if $('.moderations_manage').length > 0
		window.moderations_manage = new ModerationsManage
