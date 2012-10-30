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
		@element = $("#question")
		@id = $("#question_id").val()
		@asker_id = $("#asker_id").val()
		@user_image = $("#user_image").val()
		@user_name = $("#user_name").val()
		@name = $("#feed_name").val()
		@publication_id = $("#publication_id").val()
		@show_answer = $("#show_answer").val()
		answers = $("#question").find(".answers")
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
				@respond_to_question(parent.text(), parent.attr("answer_id"))		
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
	# target = $("h3[answer_id=#{$('#answer_id').val()}]")
	# target.click() if target.length > 0