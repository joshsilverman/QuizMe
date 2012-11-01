class Question
	id: null
	asker_id: null
	element: null
	user_image: null
	user_name: null
	name: null
	publication_id: null

	constructor: ->
		@element = $("#question")
		@id = $("#question_id").val()
		@asker_id = $("#asker_id").val()
		@user_image = $("#user_image").val()
		@user_name = $("#user_name").val()
		@name = $("#feed_name").val()
		@publication_id = $("#publication_id").val()
		@questions = $.parseJSON $("#questions").html()
		@handle_data = $.parseJSON($('#handle_data').html())
		answers = $("#question").find(".answers")
		answers.accordion({
			collapsible: true, 
			autoHeight: false,
			active: false, 
			icons: false, 
		})
		$(".tweet_button").on "click", (e) => 
			if @user_name != undefined
				parent = $(e.target).parents(".answer_container").prev("h2")
				@respond_to_question(parent.text(), parent.attr("answer_id"))	

		$('.post-question').click (a) -> question.post_edit_question(this)
		$('.post-new-question').click (a) -> question.post_new_question()
		$("#add_answer").on "click", -> question.post_new_question_add_answer()

		mixpanel.track("page_loaded", {"account" : @name, "source": source, "user_name": @user_name, "type": "question"})
		mixpanel.track_links(".answer_more", "answer_more", {"account" : @name, "source": source, "user_name": @user_name})
	
	respond_to_question: (text, answer_id) =>
		answers = @element.find(".answers")
		loading = @element.find(".loading").text("Tweeting your answer...")
		loading.fadeIn(500)
		answers.toggle(200, => answers.remove())
		params =
			"asker_id" : @asker_id
			"answer_id" : answer_id
			"post_id" : @publication_id
		$.ajax '/respond_to_question',
			type: 'POST'
			data: params
			success: (e) => 
				@element.find(".subsidiaries").show()
				subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
				subsidiary.find("p").text(e.user_message)
				subsidiary.find("img").attr("src", @user_image)
				subsidiary.find("h5").text(@user_name)
				@element.find(".parent").addClass("answered")
				loading.fadeOut(500, => 
					subsidiary.addClass("answered")
					@element.find(".subsidiaries").append(subsidiary.fadeIn(500, => @populate_response(e)))
				)
				# mixpanel.track("answered", {"account" : @name, "source": source, "user_name": @user_name, "type": "question"})				
			error: => 
				loading.text("Something went wrong, sorry!").delay(2000).fadeOut()

	populate_response: (message_hash) =>
		response = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
		response.find("p").text(message_hash.app_message) 
		response.find("h5").text(@name)
		loading = @element.find(".loading").text("Thinking...")
		if @element.find(".subsidiaries:visible").length > 0
			loading.fadeIn(500, => loading.delay(1000).fadeOut(500, => 
					@element.find(".subsidiary").after(response.fadeIn(500, => $(".more").fadeIn(500)))
					@element.find("i").show()
				)
			)
		else
			@element.find(".subsidiary").after(response.fadeIn(500))
			@element.find("i").show()

	post_new_question: () =>
		$('.ianswer').each (i, elmnt) -> 
			if elmnt.id != 'ianswer1'
				$(elmnt).remove()
		$("#add_answer").show()
		$('#ianswer1 input, #canswer input').val("")

		$('#post_question_modal .modal-header h3').html "New Question"
		$("#post_question_modal").modal()
		$("#submit_question").off "click"
		$("#submit_question").on "click", (e) => 
			e.preventDefault()
			question.post_new_question_submit()

		$('#handle_input').autocomplete
			source: @handle_data.map (h) -> h[0]
			open: (e, ui) ->
				menu = $('.ui-menu, .dropdown-menu')
				menu_items = menu.find('li')
				menu_links = menu.find('a')

				menu.removeClass()
				menu.removeAttr('style')
				menu_items.removeClass()
				menu_links.removeClass()


				menu.addClass 'dropdown-menu'
				$(this).after menu
				menu.show()
				
				menu_links.click ->
					$('#handle_input').val $(this).html()
					$('.dropdown-menu').hide()

	post_edit_question: (elmnt) =>
		question_id = $(elmnt).closest('.question-row').attr('question_id')
		q = question.questions[question_id]
		$('#question_input').val q.text

		$('.ianswer').each (i, elmnt) -> 
			if elmnt.id != 'ianswer1'
				$(elmnt).remove()
		$("#add_answer").show()
		$('#ianswer1 input').val("")

		$(q.answers).each (i, qq) ->
			if qq.correct == true
				$('#canswer input').val qq.text
				$('#canswer input').attr 'answer_id', qq.id
			else
				if $('#ianswer1 input').val() == ''
					$('#ianswer1 input').val qq.text
					$('#ianswer1 input').attr 'answer_id', qq.id
				else
					count = $(".answer").length
					clone = $("#ianswer1").clone().attr("id", "ianswer#{count}").appendTo("#answers")
					clone.find("input").attr("name", "ianswer#{count}").val(qq.text)
					clone.find("input").attr 'answer_id', qq.id
					$("#add_answer").hide() if count == 3

		$.each @handle_data, (i, r) -> $('#handle_input').val r[0] if r[1] == q.created_for_asker_id

		$('#post_question_modal .modal-header h3').html "Edit Question"
		$("#post_question_modal").modal()
		$("#submit_question").off "click"
		$("#submit_question").on "click", (e) => 
			e.preventDefault()
			question.post_edit_question_submit(q.id)

	post_new_question_submit: ->
		return if question.post_question_validate_form()

		$("#submit_question").button("loading")
		data =
			"question" : $("#question_input").val()
			#"asker_id" : window.feed.id
			"status" : $("#status").val()
			"canswer" : $("#canswer input").val()
			"ianswer1" : $("#ianswer1 input").val()
			"ianswer2" : $("#ianswer2 input").val()
			"ianswer3" : $("#ianswer3 input").val()
			"handle" : $("handle_input").val()
		$.ajax
			url: "/questions/save_question_and_answers",
			type: "POST",
			data: data,
			error: => alert_status(false),
			success: (e) => location.href = location.href.split("?")[0]

	post_edit_question_submit: (question_id) ->
		if question.post_question_validate_form()
			$("#submit_question").button("loading")
			data =
				"question" : $("#question_input").val()
				"asker_id" : question.questions[question_id]['created_for_asker_id']
				"status" : $("#status").val()
				"canswer" : $("#canswer input").val()
				"ianswer1" : $("#ianswer1 input").val()
				"ianswer2" : $("#ianswer2 input").val()
				"ianswer3" : $("#ianswer3 input").val()
				"canswer_id" : $("#canswer input").attr('answer_id')
				"ianswer1_id" : $("#ianswer1 input").attr('answer_id')
				"ianswer2_id" : $("#ianswer2 input").attr('answer_id')
				"ianswer3_id" : $("#ianswer3 input").attr('answer_id')
				"question_id" : question_id
				"handle" : $("handle_input").val()
			$.ajax
				url: "/questions/save_question_and_answers",
				type: "POST",
				data: data,
				error: => alert_status(false),
				success: (e) => 
					location.reload()

	post_new_question_add_answer: ->
		count = $(".answer").length
		return if count > 3
		clone = $("#ianswer1").clone().attr("id", "ianswer#{count}").appendTo("#answers")
		clone.find("input").attr("name", "ianswer#{count}").val("").focus()
		clone.find("input").removeAttr("answer_id")
		$("#add_answer").hide() if count == 3

	post_question_validate_form: ->
		if $("#question_input").val() == ""
			alert "Please enter a question!"
			return false
		else if $("#canswer input").val().length == 0 or $("#ianswer1 input").val().length == 0
			alert "Please enter at least one correct and incorrect answer!"
			return false
		else if @handle_data[$("#handle_input").val()] == undefined and $('#handle-selector').is(":visible")
			alert "Please enter a valid handle!"
			return false
		else
			return true

class Moderator

	constructor: ->
		$('.btn.btn-success').on "click", (e) => @respond(true, $(e.target).attr('qid'))
		$('.btn.btn-danger').on "click", (e) => @respond(false, $(e.target).attr('qid'))

	respond: (accepted, id) ->
		q = {}
		q['question_id'] = parseInt id
		q['accepted'] = accepted
		$.ajax '/moderate/update',
			type: 'POST'
			dataType: 'html'
			data: q
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) ->
				$("#question_#{q['question_id']}").fadeOut()

$ ->
	window.moderator = new Moderator if $('#moderate_questions').length > 0
	window.question = new Question if $("#question").length > 0
	question.post_new_question()
	# target = $("h3[answer_id=#{$('#answer_id').val()}]")
	# target.click() if target.length > 0