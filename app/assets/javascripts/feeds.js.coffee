class Feed
	id: null
	name: null 
	posts: []
	answered: 0
	user_name: null
	user_image: null
	conversations: null
	engagements: null
	correct: null
	constructor: ->
		# $("img").tooltip()
		@user_name = $("#user_name").val()
		@user_image = $("#user_img").val()
		@name = $("#feed_name").val()
		@id = $("#feed_id").val()
		@correct = $("#correct").val()

		@conversations = $.parseJSON($("#conversations").val())
		@engagements = $.parseJSON($("#engagements").val())

		@initialize_posts($(".conversation"))
		@initialize_infinite_scroll()
		@initialize_tooltips()
		@initialize_fix_position_listener()
		@activity_stream() 
		$(".timeago").timeago()

		$(".post_question").on "click", (e) =>
			e.preventDefault()
			@post_question()

		@post_question() if $("#question_form").val() == "true"

		$("#retweet_question").on "click", (e) => 
			e.preventDefault()
			$("#retweet_question").button("loading")
			@retweet($(e.target))
		mixpanel.track("page_loaded", {"account" : @name, "source": source, "user_name": @user_name, "type": "feed"})
		mixpanel.track_links(".tweet_button", "no_auth_tweet_click", {"account" : @name, "source": source}) if @user_name == null or @user_name == undefined
		mixpanel.track_links(".related_feed", "clicked_related", {"account" : @name, "source": source})
		$(".profile").on "click", => mixpanel.track("profile click", {"account" : @name, "source": source, "type": "activity"})
		$(".post_another").on "click", => 
			modal = $("#post_question_modal")
			$('#submit_question').button('reset')
			modal.find(".modal-body").slideToggle(250, =>
				modal.find(".message").hide()
				modal.find(".question_form").show()
			).delay(250).slideToggle(250)
	activity_stream: =>
		return unless $("#activity_stream_content").length > 0
		$.ajax '/activity_stream',
			type: 'GET'
			success: (e) => 
				container = $("#activity_stream_content")
				container.empty().append(e)
				container.find("#stream_list").hide().slideToggle(500, => 
					$("#activity_stream p").show()
					$("#activity_stream .content").dotdotdot({height: 55})
					mixpanel.track_links(".stream_item", "stream click", {"account" : @name, "source": source})					
					$(".timeago").timeago()
				)
			complete: => 
				$("#activity_stream h4 img").hide()
	initialize_fix_position_listener: =>
		$(window).on "scroll", => 
			if $(window).scrollTop() >= 204
				$("#left_column_container").css("position", "fixed").css("top", "15px")
			else
				$("#left_column_container").css("position", "").css("top", "auto")
	initialize_infinite_scroll: =>
		window.appending = false
		$(window).on "scroll", => 
			return if window.appending
			# ($(document).height() == ($(window).scrollTop() + $(window).height()))#
			if ($(window).scrollTop() >= $(document).height() - $(window).height() - 1)
				window.appending = true
				@show_more() 
		$("#posts_more").on "click", (e) => 
			e.preventDefault()
			@show_more()	
	initialize_tooltips: =>
		# $("#post_question_tooltip").tooltip
		$(".interaction").tooltip()
		$("#directory img").tooltip()
	# initialize_ask: => 
	# 	ask_element = $("#ask .question_container")
	# 	textarea = ask_element.find("textarea")
	# 	count = ask_element.find(".character_count")
	# 	button = ask_element.find(".tweet_button")
	# 	button.on "click", => 
	# 		if (140 - textarea.val().length) > 0
	# 			button.button("loading")
	# 			params = 
	# 				"text" : textarea.val()
	# 				"asker_id" : @id
	# 			$.ajax '/ask',
	# 				type: 'POST'
	# 				data: params
	# 				success: (e) =>
	# 					textarea.hide()
	# 					button.button("reset")
	# 					ask_element.find(".post_url").attr "href", "http://twitter.com/#{@user_name}/status/#{e}"
	# 					ask_element.removeClass("focus").addClass("blur")
	# 					ask_element.find(".ask_success").fadeIn(250)
	# 				error: =>
	# 					textarea.hide()
	# 					button.button("reset")
	# 					ask_element.removeClass("focus").addClass("blur")
	# 					ask_element.find(".ask_success").text("Sorry, something went wrong!").fadeIn(250)
	# 	textarea.on "focus", => 
	# 		ask_element.removeClass("blur").addClass("focus")
	# 		if textarea.val() == ""
	# 			textarea.val("@#{@name} ")
	# 		update_character_count()
	# 	textarea.on "blur", => 
	# 		if textarea.val() == "@#{@name} " or textarea.val() == ""
	# 			textarea.val("")
	# 			ask_element.removeClass("focus").addClass("blur")
	# 		update_character_count()
	# 	textarea.on "keydown", => update_character_count()
	# 	$(".ask_again").on "click", =>
	# 		ask_element.find(".ask_success").hide()
	# 		textarea.val("").fadeIn(250)
	# 	update_character_count = ->
	# 		text = 140 - textarea.val().length
	# 		count.text(text)
	# 		if text < 0
	# 			button.addClass("disabled")
	# 		else if text < 10
	# 			count.css "color", "red"
	# 			button.removeClass("disabled")
	# 		else
	# 			count.css "color", "#333"
	# 			button.removeClass("disabled")
	initialize_posts: (posts) => @posts.push(new Post post) for post in posts
	# initializeNewPostListener: =>
	# 	pusher = new Pusher('bffe5352760b25f9b8bd')
	# 	channel = pusher.subscribe(@name)
	# 	channel.bind 'new_post', (data) => @displayNewPost(data, "prepend")
	retweet: (e) =>
		id = e.attr 'publication_id'
		params = 
			"publication_id" : id
		$.ajax "/posts/retweet",
			type: 'POST',
			data: params
			complete: => 
				$("#retweet_question_modal").modal('hide')	
				$('#retweet_question').button('reset')
			success: (e) => 
				post = $(".post[post_id=#{id}]")
				post.find(".icon-retweet").fadeIn()	
				post.find(".retweet").remove()
				mixpanel.track("retweet", {"account" : @name, "source": source, "user_name": window.feed.user_name, "type": "feed"})
	post_question: =>
		# return unless window.feed.correct > 9 or $('.is_author').length > 0
		$("#post_question_modal").modal()
		$("#add_answer, #submit_question").off "click"
		$("#add_answer").on "click", => add_answer()
		$("#submit_question").on "click", (e) => 
			e.preventDefault()
			submit()
		add_answer = ->
			count = $(".answer").length
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
					error: => alert_status(false),
					success: (e) => 
						$("#question_input, #canswer input, #ianswer1 input, #ianswer2 input, #ianswer3 input").val("")
						modal.find(".question_form").hide()
						modal.find(".message").show()
						modal.find(".modal-body").slideToggle(250)
		alert_status = (status) ->
			# $('#submit_question').button('reset')
			# text = if status then "Thanks, we'll get in touch when your question is posted!" else "Something went wrong..."
			# $('#post_question_modal').modal('hide') #window.location.replace("/questions/new?asker_id=#{$("#asker_id").val()}&success=1")
			# alert text
		validate_form = ->
			if $("#question_input").val() == ""
				alert "Please enter a question!"
				return false
			else if $("#canswer input").val().length == 0 or $("#ianswer1 input").val().length == 0
				alert "Please enter at least one correct and incorrect answer!"
				return false
			else
				return true	
	show_more: => 
		last_post_id = $(".post.parent:visible").last().attr "post_id"
		if last_post_id == undefined
			$("#posts_more").text("Last Post Reached")
			$(window).off "scroll"		
			return 
		else
			$.ajax
				url: "/feeds/#{@id}/more/#{last_post_id}",
				type: "GET",
				error: => window.appending = false, 
				success: (e) => 
					if e is false
						$("#posts_more").text("Last Post Reached")
						$(window).off "scroll"					
					else
						$("#feed_content").append($(e).hide().fadeIn())
						@initialize_posts($("#feed_content .feed_section").last().find(".conversation"))
						$('.interaction').tooltip()
					window.appending = false
					$(".timeago").timeago()
	shuffle: (arr) ->
		x = arr.length
		if x is 0 then return false
		bottomAnswer = arr.length - 1
		$.each arr, (i) ->
			j = Math.floor(Math.random() * (arr.length))
			[arr[i], arr[j]] = [arr[j], arr[i]]
		$.each arr, (i) ->
			if arr[i].text.indexOf("of the above") > -1 or arr[i].text.indexOf("all of these") > -1
				[arr[bottomAnswer], arr[i]] = [arr[i], arr[bottomAnswer]]						


class Post
	id: null
	element: null
	question: null
	correct: null
	expanded: false
	asker_id: null
	image_url: null
	asker_name: null
	constructor: (element) ->
		@element = $(element)
		@id = @element.find(".post").attr "post_id"
		@question = @element.find(".question_text").text()
		@asker_id = @element.attr "asker_id"
		@image_url = @element.find(".rounded").attr "src"
		@asker_name = @element.find(".content h5").text()
		@element.on "click", (e) => @expand(e) unless $(e.target).parents(".ui-dialog").length > 0
		@element.find(".retweet").on "click", => 
			$("#retweet_question_modal").find("img").attr "src", @image_url
			$("#retweet_question_modal").find("h5").text(@asker_name)
			$("#retweet_question_modal").find("p").text(@question)
			$("#retweet_question_modal").find("#retweet_question").attr "publication_id", @id
			$("#retweet_question_modal").modal()	
		@element.hover(
			=> 
				@element.find(".retweet.rollover").css("visibility", "visible") if window.feed.user_name != undefined
				@element.find(".expand").css("color", "#08C")
				@element.find(".answered_indicator").css("opacity", ".6")
			=> 
				@element.find(".retweet.rollover").css("visibility", "hidden") unless @expanded
				@element.find(".expand").css("color", "#999") unless @expanded
				@element.find(".answered_indicator").css("opacity", ".4") unless @expanded
		)
		@element.find(".tweet_button").on "click", (e) => 
			if $("#user_name").val() != undefined
				parent = $(e.target).parents(".answer_container").prev("h3")
				@respond_to_question(parent.text(), parent.attr("answer_id"), parent.attr "correct")
		answers = @element.find(".answers")
		answers.accordion({
			collapsible: true, 
			autoHeight: false,
			active: false, 
			icons: false, 
		})		
		answers.on "accordionchange", (e, ui) => 
			if ui.newHeader.length > 0
				$(e.target).find("h3").removeClass("active_next")
				$(ui.newHeader).nextAll('h3:first').toggleClass("active_next")
			else
				$(e.target).find("h3").removeClass("active_next")
	expand: (e) =>
		return if $(e.target).parent(".answers").length > 0 or $(e.target).hasClass("answer_controls") or $(e.target).hasClass("tweet") or $(e.target).parent(".tweet").length > 0 or $(e.target).hasClass("btn") or $(e.target).hasClass("retweet") or $(e.target).hasClass("answer_link") or $(e.target).parent(".asker_link").length > 0 or $(e.target).parent(".question_via").length > 0
		if @element.hasClass("active")
			@expanded = false
			@element.find(".expand").text("Answer")
			@element.find(".subsidiaries, .loading, .answers").hide()
			@element.find(".subsidiaries, .loading, .answers").hide()
			@element.toggleClass("active", 200)
			@element.next(".conversation").removeClass("active_next")
			@element.prev(".conversation").removeClass("active_prev")	
			@element.find(".answered_indicator").css("opacity", ".4")
		else 
			@expanded = true
			@element.find(".retweet").css("visibility", "visible") if window.feed.user_name != undefined
			@element.find(".expand").text("Collapse")
			@element.find(".answers").slideToggle(200)
			@element.find(".answered_indicator").css("opacity", ".6")
			@element.find(".subsidiaries").slideToggle(200, => 
				@element.toggleClass("active", 200)
				@element.next(".conversation").addClass("active_next")
				@element.prev(".conversation").addClass("active_prev")
			)	
	respond_to_question: (text, answer_id, correct) =>
		answers = @element.find(".answers")
		loading = @element.find(".loading").text("Posting your answer...")
		loading.fadeIn(500)
		answers.slideToggle(200, => answers.remove())
		params =
			"asker_id" : @asker_id
			"post_id" : @id
			"answer_id" : answer_id
		$.ajax '/respond_to_question',
			type: 'POST'
			data: params
			success: (e) => 
				icon = @element.find(".answered_indicator")
				icon.removeClass("icon-ok-sign icon-remove-sign")
				icon.addClass(if correct == "true" then "icon-ok-sign" else "icon-remove-sign")
				@element.find(".parent").addClass("answered")
				conversation = @element.find(".subsidiaries")
				conversation.prepend($(e).hide())
				first_post = conversation.find(".post").first()
				loading.fadeOut(500, => 
					first_post.fadeIn(500, =>
						loading = @element.find(".loading").text("Thinking...")
						loading.fadeIn(500, => 
							loading.delay(1000).fadeOut(500, => 
								conversation.find(".post").last().fadeIn(500, => @show_activity())
								icon.fadeIn(250)
							)
						)
					)
				)
				# window.feed.answered += 1
				# mixpanel.track("answered", {"count" : window.feed.answered, "account" : window.feed.name, "source": source, "user_name": window.feed.user_name, "type": "feed"})				
			error: => 
				loading.text("Something went wrong, sorry!").delay(2000).fadeOut()
	# populate_response: (message_hash) =>
	# 	response = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
	# 	response.find(".content p").text(message_hash.app_message.split("http")[0]) 
	# 	response.find("h5").text(@asker_name)
	# 	response.find(".rounded").attr("src", @image_url) 
	# 	loading = @element.find(".loading").text("Thinking...")
	# 	if @element.find(".subsidiaries:visible").length > 0
	# 		loading.fadeIn(500, => loading.delay(1000).fadeOut(500, => 
	# 				@element.find(".subsidiary").after(response.fadeIn(500, => @show_activity()))
	# 				@element.find(".icon-share-alt").show()
	# 			)
	# 		)
	# 	else
	# 		@element.find(".subsidiary").after(response.fadeIn(500, => @show_activity()))
	# 		@element.find("i").show()
	show_activity: =>
		if @element.find(".activity_container:visible").length > 0
			@element.find(".user_answered").fadeIn(500)
		else
			@element.find(".user_answered").show()
			@element.find(".activity_container").fadeIn(500)
		$(".interaction").tooltip()
		@element.find(".quiz_container").fadeIn(500)


$ -> 
	if $("#post_feed").length > 0
		window.feed = new Feed 
		target = $(".post[post_id=#{$('#post_id').val()}]")
		if target.length > 0
			target.click()
			target.find("h3[answer_id=#{$('#answer_id').val()}]").click()
			$.scrollTo(target, 500)
