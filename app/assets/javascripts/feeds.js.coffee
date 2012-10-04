class Feed
	id: null
	name: null 
	questions: []
	answered: 0
	user_name: null
	user_image: null
	manager: false
	conversations: null
	engagements: null
	correct: null
	constructor: ->
		@user_name = $("#user_name").val()
		@user_image = $("#user_img").val()
		@name = $("#feed_name").val()
		@id = $("#feed_id").val()
		@correct = $("#correct").val()
		@conversations = $.parseJSON($("#conversations").val())
		@engagements = $.parseJSON($("#engagements").val())
		@manager = true if $("#manager").length > 0
		@initializeQuestions()
		$('.best_in_place').on "ajax:success", -> 
			conversation = $(this).parents(".conversation")
			if conversation.css("opacity") == "1" then conversation.css("opacity", 0.8) else conversation.css("opacity", 1)
		unless @manager
			$(window).on "scroll", => @show_more() if ($(document).height() == $(window).scrollTop() + $(window).height())
			$("#posts_more").on "click", (e) => 
				e.preventDefault()
				@show_more()
		# @initializeNewPostListener()
		$(".post_question").on "click", (e) =>
			e.preventDefault()
			@post_question()
		mixpanel.track("page_loaded", {"account" : @name, "source": source, "user_name": @user_name})
		mixpanel.track_links(".tweet_button", "no_auth_tweet_click", {"account" : @name, "source": source}) if @user_name == null or @user_name == undefined
		mixpanel.track_links(".related_feed", "clicked_related", {"account" : @name, "source": source})
		mixpanel.track_links(".leader", "clicked_leader", {"account" : @name, "source": source})
		# $("#gotham").on "click", => mixpanel.track("ad_click", {"client": "Gotham", "account" : @name, "source": source})
	initializeQuestions: => @questions.push(new Post post) for post in $(".conversation")
	# initializeNewPostListener: =>
	# 	pusher = new Pusher('bffe5352760b25f9b8bd')
	# 	channel = pusher.subscribe(@name)
	# 	channel.bind 'new_post', (data) => @displayNewPost(data, "prepend")
	post_question: =>
		return unless window.feed.correct > 9
		$("#post_question_modal").modal()
		$("#add_answer").off "click"
		$("#add_answer").on "click", => add_answer()
		$("#submit_question").off "click"
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
				$.ajax
					url: "/questions/save_question_and_answers",
					type: "POST",
					data: data,
					error: => alert_status(false),
					success: (e) => 
						$("#question_input, #canswer input, #ianswer1 input, #ianswer2 input, #ianswer3 input").val("")
						alert_status(true)

		alert_status = (status) ->
			$('#submit_question').button('reset')
			text = if status then "Thanks, we'll get in touch when your question is posted!" else "Something went wrong..."
			$('#post_question_modal').modal('hide') #window.location.replace("/questions/new?asker_id=#{$("#asker_id").val()}&success=1")
			alert text

		validate_form = ->
			if $("#question_input").val() == ""
				alert "Please enter a question!"
				return false
			else if $("#canswer input").val().length == 0 or $("#ianswer1 input").val().length == 0
				alert "Please enter at least one correct and incorrect answer!"
				return false
			else
				return true		

	displayNewPost: (data, insert_type, interaction = null) => 
		conversation = $("#post_template").clone().removeAttr("id").show()
		post = conversation.find(".post")
		post.attr("post_id", data.id)
		post.find("p").text(data.question.text)
		conversation.css "visibility", "hidden"
		if interaction != null and interaction != undefined
			post.find(".answers").remove()
			post.addClass("answered")
			for response, i in interaction[0].posts
				if String(response.user_id) == @id
					handle = @name
					image = null
					target = @user_name
				else
					handle = @user_name
					image = @user_image
					target = @name
				subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
				subsidiary.find("p").text("@#{target} #{response.text} #{data.url}") 
				subsidiary.find("h5").text(handle)
				subsidiary.find("img").attr("src", image) unless image == null
				subsidiary.addClass("answered") if i < (interaction[0].posts.length - 1)
				conversation.find(".subsidiaries").append(subsidiary.show())
				conversation.find("i").show()
		else
			answers_element = post.find(".answers")
			answers = data.question.answers
			for answer, i in @shuffle(answers)
				if i < (answers.length - 1) then border = "bottom_border" else border = ""
				if answer.correct			
					answers_element.append("<h3 correct='true' class='#{border}' answer_id='#{answer.id}'>#{answer.text}</h3>")
				else
					answers_element.append("<h3 correct='false' class='#{border}' answer_id='#{answer.id}'>#{answer.text}</h3>")
				clone = $("#answer_template").clone().removeAttr('id')
				clone.find("#answer").text(answer.text)
				clone.find("#url").text(data.url)
				answers_element.append(clone)
		if insert_type == "prepend"
			$("#feed_content").prepend(conversation)
		else
			conversation.insertBefore("#posts_more")
		conversation.css('visibility','visible').hide().fadeIn('slow')
		@questions.push(new Post conversation)
	show_more: => 
		last_post_id = $(".post.parent:visible").last().attr "post_id"
		if last_post_id == undefined
			$("#posts_more").text("Last Post Reached")
			$(window).off "scroll"		
			return 
		else
			$.getJSON "/feeds/#{@id}/more/#{last_post_id}", (posts) => 
				if posts.publications.length > 0
					for post in posts.publications
						@displayNewPost(post, "append", posts.responses[post.id]) 
				else
					$("#posts_more").text("Last Post Reached")
					$(window).off "scroll"
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
	answers: []
	correct_responses: ["That's right!","Correct!","Yes!","That's it!","You got it!","Perfect!"]
	correct_complements: ["Way to go","Keep it up","Nice job","Nice work","Booyah","Nice going","Hear that? That's the sound of AWESOME happening",""]
	incorrect_responses: ["Hmmm, not quite.","Uh oh, that's not it...","Sorry, that's not what we were looking for.","Nope. Time to hit the books!","Sorry. Close, but no cigar.","Not quite.","That's not it."]

	constructor: (element) ->
		@answers = []
		@element = $(element)
		@id = @element.find(".post").attr "post_id"
		@question = @element.find(".question").text()
		@answers.push(new Answer answer, @) for answer in @element.find(".answer")
		@element.on "click", (e) => @expand(e) unless $(e.target).parents(".ui-dialog").length > 0
		# @element.find("li").on "click", (e) => @update_engagement_type(e)
		@element.find(".tweet_button").on "click", (e) => 
			if $("#user_name").val() != undefined
				parent = $(e.target).parents(".answer_container").prev("h3")
				@respond_to_question(parent.text(), parent.attr("answer_id"))
		answers = @element.find(".answers")
		if $("#manager").length > 0 then disabled = true else disabled = false
		answers.accordion({
			collapsible: true, 
			autoHeight: false,
			active: false, 
			icons: false, 
			disabled: disabled
		})		
		answers.on "accordionchange", (e, ui) => 
			if ui.newHeader.length > 0
				$(e.target).find("h3").removeClass("active_next")
				$(ui.newHeader).nextAll('h3:first').toggleClass("active_next")
			else
				$(e.target).find("h3").removeClass("active_next")
	expand: (e) =>
		if window.feed.manager
			if $(e.target).hasClass("link_post")
				@link_post($(e.target))
				return
			else if $(e.target).parents("#classify").length > 0 or $(e.target).is("#classify")	
				return
			else
				@open_reply_modal(e) 
				return
		return if $(e.target).parent(".answers").length > 0 or $(e.target).hasClass("answer_controls") or $(e.target).hasClass("tweet") or $(e.target).parent(".tweet").length > 0 or $(e.target).hasClass("btn")
		if $(e.target).hasClass("conversation") then post = $(e.target) else post = $(e.target).closest(".conversation")
		if post.hasClass("active")
			post.find(".subsidiaries, .loading").hide()
			post.toggleClass("active", 200)
			post.next(".conversation").removeClass("active_next")
			post.prev(".conversation").removeClass("active_prev")	
			post.find(".answers").hide()
		else 
			post.find(".answers").toggle(200)
			post.find(".subsidiaries").toggle(200, => 
				post.toggleClass("active", 200)
				post.next(".conversation").addClass("active_next")
				post.prev(".conversation").addClass("active_prev")
			)	
	respond_to_question: (text, answer_id) =>
		answers = @element.find(".answers")
		loading = @element.find(".loading").text("Tweeting your answer...")
		loading.fadeIn(500)
		answers.toggle(200, => answers.remove())
		params =
			"asker_id" : window.feed.id
			"post_id" : @id
			"answer_id" : answer_id
			# "text" : text #This will eventually be any custom text (?)
		$.ajax '/respond_to_question',
			type: 'POST'
			data: params
			success: (e) => 
				subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
				subsidiary.find("p").text(e.user_message)
				subsidiary.find("img").attr("src", window.feed.user_image)
				subsidiary.find("h5").text(window.feed.user_name)
				@element.find(".parent").addClass("answered")
				loading.fadeOut(500, => 
					subsidiary.addClass("answered")
					@element.find(".subsidiaries").append(subsidiary.fadeIn(500, => @populate_response(e)))
				)
				window.feed.answered += 1
				mixpanel.track("answered", {"count" : window.feed.answered, "account" : window.feed.name, "source": source, "user_name": window.feed.user_name})				
			error: => 
				loading.text("Something went wrong, sorry!").delay(2000).fadeOut()
	populate_response: (message_hash) =>
		response = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
		response.find("p").text(message_hash.app_message) 
		response.find("h5").text(window.feed.name)
		loading = @element.find(".loading").text("Thinking...")
		if @element.find(".subsidiaries:visible").length > 0
			loading.fadeIn(500, => loading.delay(1000).fadeOut(500, => 
					@element.find(".subsidiary").after(response.fadeIn(500))
					@element.find("i").show()
				)
			)
		else
			@element.find(".subsidiary").after(response.fadeIn(500))
			@element.find("i").show()	
	update_engagement_type: (event) =>
		event.preventDefault()
		target = $(event.target)
		switch target.attr "engagement_type"
			when "mention reply"
				title = "Reply"
				@link_post(target)
			when "mention"
				add_class = "btn-info"
				title = "Mention"
			when "share"
				add_class = "btn-success"
				title = "Retweet"
			when "spam"
				add_class = "btn-warning"
				title = "Spam"
			when "pm"
				add_class = "btn-inverse"
				title = "Private Message"				
		group = target.parents(".btn-group")
		group.find(".btn").removeClass("btn-warning btn-success btn-info btn-inverse").addClass(add_class)
		group.find(".dropdown-toggle").text(title)
		params = 
			id: @id
			engagement_type: target.attr "engagement_type"
		$.ajax "/posts/update_engagement_type",
			type: 'POST'
			data: params
			# success: (e) => 		
	open_reply_modal: (event) =>
		post = $(event.target)
		post = post.parents(".post") unless post.hasClass "post"
		window.post = post
		username = post.find('h5').html()
		correct = null
		publication_id = null
		tweet = ''
		$("#respond_modal").dialog
			title: "Reply to #{username}"
			width: 521
			modal: true
		$("button.btn.correct").off()
		$("button.btn.correct").on 'click', ()=>
			correct = true
			response = @correct_responses[Math.floor (Math.random() * @correct_responses.length )]
			complement = @correct_complements[Math.floor (Math.random() * @correct_complements.length )]
			$(".modal_body textarea").html("@#{username} #{response} #{complement}")
		$("button.btn.incorrect").off()
		$("button.btn.incorrect").on 'click', ()=>
			correct = false
			$(".modal_body textarea").html("@#{username} #{@incorrect_responses[Math.floor (Math.random() * @incorrect_responses.length )]}")
		$("#tweet.btn.btn-info").off()
		$("#tweet.btn.btn-info").on 'click', () =>
			tweet = $("#respond_modal").find("textarea").val()
			return if tweet == ""
			parent_index = window.feed.conversations[@id]['posts'].length - 1
			parent_post = window.feed.conversations[@id]['posts'][parent_index]
			publication_id = parent_post['publication_id'] unless parent_post == undefined
			params =
				"interaction_type" : post.attr "interaction_type"
				"asker_id" : window.feed.id
				"in_reply_to_post_id" : @id
				"in_reply_to_user_id" : window.feed.engagements[@id]['user_id']
				"message" : tweet
				"username" : username
			params["correct"] = correct if correct != null
			params["publication_id"] = publication_id if publication_id
			$.ajax '/manager_response',
				type: 'POST'
				data: params
				success: (e) =>
					$("#respond_modal").find("textarea").val("")
					$("#respond_modal").dialog('close')
					$(".post[post_id=#{@id}]").children('#classify').hide()
					$(".post[post_id=#{@id}]").children('.icon-share-alt').show()
		convo =  window.feed.conversations[post.attr('post_id')]
		$('.modal_conversation_history > .conversation').html('')

		user_post = window.feed.engagements[@id]
		subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
		subsidiary.find("p").text("#{user_post['text']}") 
		subsidiary.find("h5").text("#{convo['users'][user_post['user_id']]['twi_screen_name']}")
		image = convo['users'][user_post['user_id']]['twi_profile_img_url']
		subsidiary.find("img").attr("src", image) unless image == null
		#subsidiary.addClass("answered") if i < (interaction[0].posts.length - 1)
		$('.modal_conversation_history').find(".conversation").append(subsidiary.show())

		$.each convo['posts'], (i, p) ->
			subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
			subsidiary.find("p").text("#{p['text']}") 
			subsidiary.find("h5").text("#{convo['users'][p['user_id']]['twi_screen_name']}")
			image = convo['users'][p['user_id']]['twi_profile_img_url']
			subsidiary.find("img").attr("src", image) unless image == null
			#subsidiary.addClass("answered") if i < (interaction[0].posts.length - 1)
			$('.modal_conversation_history').find(".conversation").append(subsidiary.show())
			if i == 0
				html = "<div class='subsidiary post'>"
				$.each convo['answers'], (j, a) ->
					html+= "<div class='answers rounded border'><h3 style='#{'color: green;' if a['correct']}'>#{a['text']}</h3></div>"
				html += "</div>"
				$('.modal_conversation_history').find(".conversation").append(html)


	link_post: (event) =>
		window.post = event
		post = event.parents('.post').find('.content').html()
		$("#link_post_modal").dialog
			title: "Link Post"
			width: 530
			height: 600
			modal: true
		$("#link_post_modal .parent_post .content ").html(post)
		$("#link.btn.btn-info").click ()=>
			params =
			"link_to_post_id" : $("input:checked").val()
			"post_id" : @id
			# "text" : text #This will eventually be any custom text (?)
			$.ajax '/link_to_post',
				type: 'POST'
				data: params
				success: (e) =>
					$("#link_post_modal").dialog('close')


class Answer
	post: null
	element: null
	correct: false
	constructor: (element, post) ->
		@post = post
		@element = $(element)
		@correct = true if @element.hasClass("correct")
		@element.on "click", =>
			@post.answered(@correct)
			@element.css("color", "#800000") unless @correct
			answer.element.off "click" for answer in @post.answers


$ -> 
	if $("#feed").length > 0
		window.feed = new Feed 
		target = $(".post[post_id=#{$('#post_id').val()}]")
		if target.length > 0
			target.click()
			target.find("h3[answer_id=#{$('#answer_id').val()}]").click()
			$.scrollTo(target, 500)
