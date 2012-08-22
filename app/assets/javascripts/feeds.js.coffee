class Feed
	id: null
	name: null 
	questions: []
	answered: 0
	user_name: null
	user_image: null
	constructor: ->
		@user_name = $("#user_name").val()
		@user_image = $("#user_img").val()
		@name = $("#feed_name").val()
		@id = $("#feed_id").val()
		@initializeQuestions()
		target = $(".post[post_id=#{$('#post_id').val()}]")
		@scroll_to_question(target) if target.length > 0
		$(window).on "scroll", => @show_more() if ($(document).height() == $(window).scrollTop() + $(window).height())
		$("#posts_more").on "click", (e) => 
			e.preventDefault()
			@show_more()
		# @initializeNewPostListener()
		# mixpanel.track("page_loaded", {"account" : @name, "source": source})
		# $("#gotham").on "click", => mixpanel.track("ad_click", {"client": "Gotham", "account" : @name, "source": source})
	initializeQuestions: => @questions.push(new Post post) for post in $(".conversation")
	scroll_to_question: (target) =>
		target.click()
		target.find("h3[answer_id=#{$('#answer_id').val()}]").click()
		$.scrollTo(target, 500)
	initializeNewPostListener: =>
		pusher = new Pusher('bffe5352760b25f9b8bd')
		channel = pusher.subscribe(@name)
		channel.bind 'new_post', (data) => @displayNewPost(data, "prepend")
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
    
		bottomAnswer = arr.length-1
		$.each arr, (i) ->
			j = Math.floor(Math.random() * (arr.length))
			[arr[i], arr[j]] = [arr[j], arr[i]] # use pattern matching to swap
    
		$.each arr, (i) ->
			if arr[i].text.indexOf("of the above") > -1 or arr[i].text.indexOf("all of these") > -1
				[arr[bottomAnswer], arr[i]] = [arr[i], arr[bottomAnswer]]						


class Post
	id: null
	element: null
	question: null
	correct: null
	answers: []
	constructor: (element) ->
		@answers = []
		@element = $(element)
		@id = @element.find(".post").attr "post_id"
		@question = @element.find(".question").text()
		@answers.push(new Answer answer, @) for answer in @element.find(".answer")
		@element.on "click", (e) => @expand(e)
		@element.find(".btn").on "click", (e) => 
			if $("#user_name").val() != undefined
				parent = $(e.target).parents(".answer_container").prev("h3")
				@respond(parent.text(), parent.attr("answer_id"))
		# @element.on "mouseenter", => 
		# 	if @correct == true
		# 		@element.find("i").animate({color: "#0B7319"}, 0)
		# 	else
		# 		@element.find("i").animate({color: "#C43939"}, 0)
		# @element.on "mouseleave", => @element.find("i").animate({color: "black"}, 0)
		answers = @element.find(".answers")
		answers.accordion({
			collapsible: true, 
			autoHeight: false,
			active: false, 
			icons: false
		})		
		answers.on "accordionchange", (e, ui) => 
			if ui.newHeader.length > 0
				$(e.target).find("h3").removeClass("active_next")
				$(ui.newHeader).nextAll('h3:first').toggleClass("active_next")
			else
				$(e.target).find("h3").removeClass("active_next")
	expand: (e) =>
		return if $(e.target).parent(".answers").length > 0 or $(e.target).hasClass("answer_controls") or $(e.target).hasClass("tweet") or $(e.target).parent(".tweet").length > 0 or $(e.target).hasClass("btn")
		if $(e.target).hasClass("conversation") then post = $(e.target) else post = $(e.target).closest(".conversation")
		if post.hasClass("active")
			post.find(".subsidiaries, .loading").hide()
			post.toggleClass("active", 200)
			post.next(".conversation").removeClass("active_next")
			post.prev(".conversation").removeClass("active_prev")	
			post.find(".answers").hide()
			# @element.find("i").animate({color: "black"}, 0)
		else 
			post.find(".answers").toggle(200)
			post.find(".subsidiaries").toggle(200, => 
				post.toggleClass("active", 200)
				post.next(".conversation").addClass("active_next")
				post.prev(".conversation").addClass("active_prev")
			)
			# if @correct == true
			# 	@element.find("i").animate({color: "#0B7319"}, 0)
			# else
			# 	@element.find("i").animate({color: "#C43939"}, 0)			
	respond: (text, answer_id) =>
		answers = @element.find(".answers")
		loading = @element.find(".loading").text("Tweeting your answer...")
		loading.fadeIn(500)
		answers.toggle(200, => answers.remove())
		params =
			"asker_id" : window.feed.id
			"post_id" : @id
			"answer_id" : answer_id
			# "text" : text #This will eventually be any custom text (?)
		$.ajax '/respond',
			type: 'POST'
			data: params
			success: (e) => 
				subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
				subsidiary.find("p").text("@#{window.feed.name} #{text} #{e.url}")
				subsidiary.find("img").attr("src", window.feed.user_image)
				subsidiary.find("h5").text(window.feed.user_name)
				@element.find(".parent").addClass("answered")
				loading.fadeOut(500, => 
					subsidiary.addClass("answered")
					@element.find(".subsidiaries").append(subsidiary.fadeIn(500, => @populate_response(e)))
				)
			error: => 
				loading.text("Something went wrong, sorry!").delay(2000).fadeOut()
	populate_response: (message_hash) =>
		response = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
		response.find("p").text("@#{window.feed.user_name} #{message_hash.message} #{message_hash.url}") 
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
	# answered: (correct) =>
	# 	window.feed.answered += 1
	# 	mixpanel.track("answered", {"count" : window.feed.answered, "account" : window.feed.name, "source": source})
	# 	if correct
	# 		@element.css("background", "rgba(0, 59, 5, .2)")
	# 	else
	# 		@element.css("background", "rgba(128, 0, 0, .1)")
	# 	for answer in @answers
	# 		answer.element.css("background", "gray")
	# 		if answer.correct
	# 			answer.element.css("color", "#003B05")
	# 		else
	# 			answer.element.css("color", "#bbb")


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


$ -> window.feed = new Feed if $("#feed").length > 0
