class ModerationsManage
	constructor: ->
		@askers = $.parseJSON($("#askers").val())
		@display_notifications = $('#display_notifications').val()
		@is_question_supermod = $('#is_question_supermod').val()
		puts @is_question_supermod

		$(".quick-reply").on "click", @quick_reply

		$('.replies .btn').on 'click', (e) =>
			element = $(e.target)
			e.stopImmediatePropagation() if element.hasClass 'active'
			# @submit_question_feedback(element)
			@edit_question(element) if element.hasClass('btn-danger') and @is_question_supermod == 'false'

		# # toggle open post
		$('.conversation').first().addClass 'active'
		$(".conversation").on "click", ->
			$('.conversation').removeClass 'active'
			$(this).addClass 'active'
			
		@hotkeys = new Hotkeys false
		$("#post_question_modal #add_answer").on "click", @add_answer
		$("#post_question_modal #submit_question").on "click", (e) =>
			e.preventDefault()
			@submit_question_edit()

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
		user_name = conversation.find(".content h5").text().trim().split(" ")[0]
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

	edit_question: (element) =>
		conversation = element.parents('.conversation')
		question_id = conversation.find('.post').attr 'question_id'
		$('#question_input').attr('question_id', question_id).val(conversation.find('.question p').text())
		answers = conversation.find('.answer')
		$(".ianswer").remove()
		answers.each (i, answer) ->
			text = $(answer).text().trim()
			if i == 0
				$('#canswer input').val(text)
				$('#canswer').attr 'answer_id', $(answer).attr 'answer_id'
			else
				clone = $("#canswer").clone().attr('class', 'ianswer').attr("id", "ianswer#{i}").appendTo("#answers")
				clone.find("input").attr("name", "ianswer#{i}").attr('placeholder', 'Incorrect answer').val(text)
				clone.find('i').attr('class', 'icon-remove')
				clone.attr 'answer_id', $(answer).attr 'answer_id'
		$("#add_answer").show() if answers.length < 4
		$('#post_question_modal .modal-header h3').html "Edit Question"
		$("#post_question_modal").modal()
		$("#post_question_modal").css("top", $(window).scrollTop() + 10) if $(window).width() < 480

	add_answer: =>
		count = $("#post_question_modal .answer").length
		return if count > 3
		clone = $("#canswer").clone().attr("id", "ianswer#{count}").attr('class', 'ianswer')
		clone.find("input").attr("name", "ianswer#{count}").attr('placeholder', 'Incorrect answer').val("").focus()
		clone.find('i').attr('class', 'icon-remove')
		clone.removeAttr('answer_id', '')
		clone.appendTo("#answers")
		$("#add_answer").hide() if count == 3
	
	submit_question_edit: =>
		if @validate_form()
			$("#submit_question").button("loading")
			params =
				'question_id': $('#question_input').attr 'question_id'
				'text': $("#question_input").val()
				'answers': []
			$('#post_question_modal .answer').each (i, answer) ->
				parent = $(answer).parent()
				answer_params = 
					'id': parent.attr 'answer_id'
					'text': $(answer).find('input').val().trim()
					'correct': parent.attr('id') == 'canswer'
				params['answers'].push(answer_params)
			$.post '/questions/update_question_and_answers', params, ->
				$("#question_input, #canswer input, #ianswer1 input, #ianswer2 input, #ianswer3 input").val("")
				$("#post_question_modal").modal('hide')	

	validate_form: =>
		if $("#question_input").val() == ""
			alert "Please enter a question!"
			return false
		else if $("#canswer input").val().length == 0 or $("#ianswer1 input").val().length == 0
			alert "Please enter at least one correct and incorrect answer!"
			return false
		else
			return true	

$ ->
	if $('.moderations_manage').length > 0
		window.moderations_manage = new ModerationsManage
