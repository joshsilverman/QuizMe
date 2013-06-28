class ModerationsManage
	constructor: ->
		@askers = $.parseJSON($("#askers").val())
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

		$.post '/moderations', params, (trigger_type_id) ->
			conversation.addClass('moderated')
			window.moderations_manage.notify(conversation, trigger_type_id) unless trigger_type_id == null

		conversation.addClass "dim"
		window.moderations_manage.hotkeys.prev() if conversation.nextAll(".conversation").length < 1
	
	notify: (conversation, trigger_type_id) =>
		user_name = conversation.find(".content h5").text().trim()
		switch trigger_type_id
			when 1 then text = "Sent correct grade post to #{user_name}."
			when 2 then text = "Sent incorrect grade post to #{user_name}."
			when 3 then text = "Sent tell message to #{user_name}."
			when 5 then text = "Hid #{user_name}'s post."
		$.gritter.add
			title: conversation.find(".asker_twi_screen_name").text().split(" ")[1]
			text: text
			image: @askers[conversation.attr('asker_id')]['twi_profile_img_url']
			time: 9000

$ ->
	if $('.moderations_manage').length > 0
		window.moderations_manage = new ModerationsManage
