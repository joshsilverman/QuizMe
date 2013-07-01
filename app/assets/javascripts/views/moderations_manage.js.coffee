class ModerationsManage
	constructor: ->
		@askers = $.parseJSON($("#askers").val())
		@display_notifications = $('#display_notifications').val()
		console.log @display_notifications
		$(".quick-reply").on "click", @quick_reply

		# # toggle open post
		$('.conversation').first().addClass 'active'
		$(".conversation").on "click", ->
			$('.conversation').removeClass 'active'
			$(this).addClass 'active'

		@hotkeys = new Hotkeys false

	quick_reply: ->
		elem = $(this)
		selected_type_id = elem.data 'type_id'
		conversation = elem.closest('.conversation')
		params =
			type_id: selected_type_id
			post_id: elem.closest(".post").attr 'post_id'
		
		window.moderations_manage.notify(conversation, selected_type_id) if selected_type_id == 5 or selected_type_id == 6

		$.post '/moderations', params, (type_id) ->
			conversation.addClass('moderated')
			window.moderations_manage.notify(conversation, type_id) unless type_id == false or selected_type_id == 5 or selected_type_id == 6

		conversation.addClass "dim"
		window.moderations_manage.hotkeys.prev() if conversation.nextAll(".conversation").length < 1
	
	notify: (conversation, type_id) =>
		return unless @display_notifications == 'true'
		user_name = conversation.find(".content h5").text().trim()
		switch type_id
			when null then text = "Thanks, I'll confirm that and get it out shortly!"
			when 1 then text = "Sent correct grade post to #{user_name}."
			when 2 then text = "Sent incorrect grade post to #{user_name}."
			when 3 then text = "Sent tell message to #{user_name}."
			when 5 then text = "Hid #{user_name}'s post."
			when 6 then text = "Hid #{user_name}'s post."
		$.gritter.add
			title: conversation.find(".asker_twi_screen_name").text().split(" ")[1]
			text: text
			image: @askers[conversation.attr('asker_id')]['twi_profile_img_url']
			time: 6000

$ ->
	if $('.moderations_manage').length > 0
		window.moderations_manage = new ModerationsManage
