class ModerationsManage
	constructor: ->
		@askers = $.parseJSON($("#askers").val())
		@display_notifications = $('#display_notifications').val()
		$(".quick-reply").on "click", @quick_reply
		$('.question_feedback').on 'click', (e) =>
			element = $(e.target)
			e.stopImmediatePropagation() if element.hasClass 'active'
			@submit_question_feedback(element)

		# # toggle open post
		$('.conversation').first().addClass 'active'
		$(".conversation").on "click", ->
			$('.conversation').removeClass 'active'
			$(this).addClass 'active'
			
		@hotkeys = new Hotkeys false

	submit_question_feedback: (element) =>
		conversation = element.closest('.conversation')
		conversation.addClass "dim"

		if element.hasClass 'btn-success'
			return if element.hasClass 'disabled'
			conversation.find('.btn').addClass('disabled')
		else
			return if element.hasClass 'disabled'
			return if element.hasClass 'active'
			conversation.find('.btn-success').addClass('disabled')

		params =
			type_id: element.data 'type_id'
			question_id: element.closest(".post").attr 'question_id'
		@create_moderation(params, conversation, false)

	quick_reply: ->
		elem = $(this)
		selected_type_id = elem.data 'type_id'
		conversation = elem.closest('.conversation')
		conversation.addClass "dim"
		window.moderations_manage.hotkeys.prev() if conversation.nextAll(".conversation").length < 1
		
		params =
			type_id: selected_type_id
			post_id: elem.closest(".post").attr 'post_id'
		window.moderations_manage.create_moderation(params, conversation)
		window.moderations_manage.notify(conversation, selected_type_id) if selected_type_id == 5 or selected_type_id == 6
	
	create_moderation: (params, conversation, notify = true) =>
		$.post '/moderations', params, (type_id) ->
			conversation.addClass('moderated')
			window.moderations_manage.notify(conversation, type_id) unless params['type_id'] == 5 or params['type_id'] == 6 or notify == false

	notify: (conversation, type_id) =>
		return if type_id == false
		return unless @display_notifications == 'true'
		user_name = conversation.find(".content h5").text().trim()
		switch type_id
			when null then text = "Thanks, I'll confirm that and get it out shortly!"
			when 1 then text = "Sent correct grade post to #{user_name}."
			when 2 then text = "Sent incorrect grade post to #{user_name}."
			when 3 then text = "Sent tell message to #{user_name}."
			when 5 then text = "Hid #{user_name}'s post."
			when 6 then text = "I'll take a look at that soon."
		$.gritter.add
			title: conversation.find(".asker_twi_screen_name").text().split(" ")[1]
			text: text
			image: @askers[conversation.attr('asker_id')]['twi_profile_img_url']
			time: 5000

$ ->
	if $('.moderations_manage').length > 0
		window.moderations_manage = new ModerationsManage
