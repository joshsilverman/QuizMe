class Question
	id: null
	asker_id: null
	element: null
	user_image: null
	user_name: null
	name: null
	publication_id: null
	show_answer: null

	constructor: ->
		console.log 'question'
		@element = $("#question")
		@id = $("#question_id").val()
		@asker_id = $("#asker_id").val()
		@user_image = $("#user_image").val()
		@user_name = $("#user_name").val()
		@name = $("#feed_name").val()
		@publication_id = $("#publication_id").val()
		@show_answer = $("#show_answer").val()
		@questions = $.parseJSON $("#questions").html()
		@handle_data = $.parseJSON($('#handle_data').html())
		answers = $("#question").find(".answers")
		@initialize_tooltips()
		if @show_answer=='true' then disabled = true else disabled = false
		answers.accordion({
			collapsible: true, 
			autoHeight: false,
			active: false, 
			icons: false, 
			disabled: disabled
		})
		$(".tweet_button").on "click", (e) => 
			if @user_name != undefined
				parent = $(e.target).parents(".answer_container").prev("h2")
				@respond_to_question(parent.text(), parent.attr("answer_id"), parent.attr "correct")	
		$('.post-question').click (a) -> question.post_edit_question(this)
		$("#add_answer").on "click", -> question.post_new_question_add_answer()

		mixpanel.track("page_loaded", {"account" : @name, "source": source, "user_name": @user_name, "type": "question"})
		mixpanel.track_links(".answer_more", "answer_more", {"account" : @name, "source": source, "user_name": @user_name})
		mixpanel.track_links(".auth_link", "redirected to authorize", {"account" : @name, "source": source})

		#allow questions index to filter and make sure selector set right
		$('#askers_select select').change -> window.location = "/questions/asker/" + $(this).children(":selected").attr('value')
		$("#askers_select option[value=#{$('#asker_id').html()}]").attr 'selected', true if $('#askers_select select')	

		$(".contributor").tooltip()

		$("#question.index .status .label").click -> question.change_status $(this)

	initialize_tooltips: =>
		$(".interaction").tooltip()
	respond_to_question: (text, answer_id, correct) =>
		answers = @element.find(".answers")
		loading = @element.find(".loading").text("Posting your answer...")
		loading.fadeIn(500)
		answers.toggle(200, => answers.remove())
		params =
			"asker_id" : @asker_id
			"answer_id" : answer_id
			"publication_id" : @publication_id
		$.ajax '/respond_to_question',
			type: 'POST'
			data: params
			success: (e) => 
				if e == ""
					loading.text("Something went wrong, sorry!")
				else
					icon = @element.find(".answered_indicator")
					icon.removeClass("icon-ok-sign icon-remove-sign")
					icon.addClass(if correct == "true" then "icon-ok-sign" else "icon-remove-sign")
					@element.find(".parent").addClass("answered")
					conversation = @element.find(".subsidiaries")
					conversation.show()
					conversation.prepend($(e).hide())
					first_post = conversation.find(".post").first()
					loading.fadeOut(500, => 
						first_post.fadeIn(500, =>
							loading = @element.find(".loading").text("Thinking...")
							loading.fadeIn(500, => loading.delay(1000).fadeOut(500, => 
									first_post.next().fadeIn(500, => @show_activity())
									icon.fadeIn(250)
								)
							)						
						)
					)
			error: => 
				loading.text("Something went wrong, sorry!")

	# populate_response: (message_hash) =>
	# 	response = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
	# 	response.find("p").text(message_hash.app_message) 
	# 	response.find("h5").text(@name)
	# 	loading = @element.find(".loading").text("Thinking...")
	# 	if @element.find(".subsidiaries:visible").length > 0
	# 		loading.fadeIn(500, => loading.delay(1000).fadeOut(500, => 
	# 				@element.find(".subsidiary").after(response.fadeIn(500, => $(".more").fadeIn(500)))
	# 				@element.find("i").show()
	# 			)
	# 		)
	# 	else
	# 		@element.find(".subsidiary").after(response.fadeIn(500))
	# 		@element.find("i").show()
	show_activity: =>
		if @element.find(".activity_container:visible").length > 0
			@element.find(".user_answered").fadeIn(500)
		else
			@element.find(".user_answered").show()
			@element.find(".activity_container").fadeIn(500)
		$(".interaction").tooltip()
		@element.find(".quiz_container").fadeIn(500)			

	post_edit_question: (elmnt) =>
		question_id = $(elmnt).closest('.question-row').attr('question_id')
		q = question.questions[question_id]
		$('#question_input').val q.text

		if $(elmnt).hasClass "pending" then $("#approve_question").css "display", "inline" else $("#approve_question").css "display", "none"

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

		$('#post_question_modal .modal-header h3').html "Edit Question"
		$("#post_question_modal").modal()
		$("#submit_question").off "click"
		$("#submit_question").on "click", (e) => 
			e.preventDefault()
			question.post_edit_question_submit(q.id)

		# $('.accept').off "click"
		# $('.reject').off "click"
		# $('.accept').on "click", (e) => @respond(true, question_id)
		# $('.reject').on "click", (e) => @respond(false, question_id)				

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
		else
			return true

	change_status: (label) ->
		window.label = label
		question_id = label.closest('.question-row').attr('question_id')
		accepted = false if label.hasClass 'approved'
		accepted = true if label.hasClass 'rejected'
		accepted = true if label.hasClass 'pending'

		q = {}
		q['question_id'] = question_id
		q['accepted'] = accepted
		$.ajax '/moderate/update',
			type: 'POST'
			dataType: 'html'
			data: q
			error: (jqXHR, textStatus, errorThrown) ->
				console.log "AJAX Error: #{errorThrown}"
			success: (data, textStatus, jqXHR) ->
				label.removeClass('approved rejected pending label-success label-important')
				if data == "true"
					label.addClass 'approved label-success'
					label.text 'Accepted'
				else
					label.addClass 'rejected label-important'
					label.text 'Rejected'

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

class Card
	constructor: ->
		$(".answers").accordion({
			collapsible: true, 
			autoHeight: false,
			active: false, 
			icons: false, 
			disabled: true
		})

class Author
	constructor: ->
		@id = $("#asker_id").val()
		$('#askers_select select').change -> window.location = "/users/#{$('#user_id').val()}/questions/" + $(this).children(":selected").attr('value')
		$("#question_input").on "focus", => $(".answer_area").show()
		$("#add_answer, #submit_question").off "click"
		console.log $("#add_answer")
		$("#add_answer").on "click", => add_answer()

		$("#submit_question").on "click", (e) => 
			e.preventDefault()
			submit()
		add_answer = ->
			count = $(".answer_area .answer").length
			return if count > 3
			clone = $("#ianswer1").clone().attr("id", "ianswer#{count}").appendTo("#answers")
			clone.find("input").attr("name", "ianswer#{count}").val("").focus()
			$("#add_answer").hide() if count == 3
		submit = ->
			if validate_form()
				$("#submit_question").button("loading")
				data =
					"question" : $("#question_input").val()
					"asker_id" : window.feed.id
					"status" : $("#status").val()
					"canswer" : $("#canswer input").val()
					"ianswer1" : $("#ianswer1 input").val()
					"ianswer2" : $("#ianswer2 input").val()
					"ianswer3" : $("#ianswer3 input").val()
				$("#submit_question").button("loading")
				modal = $("#post_question_modal")
				modal.find(".modal-body").slideToggle(250)
				$.ajax
					url: "/questions/save_question_and_answers",
					type: "POST",
					data: data,
					error: => alert "Sorry, something went wrong!",
					success: (e) => document.location.reload(true)
		validate_form = ->
			if $("#question_input").val() == ""
				alert "Please enter a question!"
				return false
			else if $("#canswer input").val().length == 0 or $("#ianswer1 input").val().length == 0
				alert "Please enter at least one correct and incorrect answer!"
				return false
			else
				return true			

$ ->
	window.moderator = new Moderator if $('#moderate_questions').length > 0
	window.question = new Question if $("#question").length > 0
	window.card = new Card if $(".answer_widget").length > 0
	window.feed = new Author if $('#author_dashboard').length > 0
	# target = $("h3[answer_id=#{$('#answer_id').val()}]")
	# target.click() if target.length > 0