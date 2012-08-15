class Feed
	id: null
	name: null 
	questions: []
	answered: 0
	user_name: null
	constructor: ->
		@user_name = $("#user_name").val()
		@name = $("#feed_name").val()
		@id = $("#feed_id").val()
		@initializeQuestions()
		target = $(".post[post_id=#{$('#post_id').val()}]")
		if target.length > 0
			$.scrollTo(target, 500)
			target.click()
			target.find("h3[answer_id=#{$('#answer_id').val()}]").click()
		$(window).on "scroll", => @showMore() if ($(document).height() == $(window).scrollTop() + $(window).height())
		# @initializeNewPostListener()
		# $("#show_more").on "click", => @showMore()
		# mixpanel.track("page_loaded", {"account" : @name, "source": source})
		# $("#gotham").on "click", => mixpanel.track("ad_click", {"client": "Gotham", "account" : @name, "source": source})
	initializeQuestions: => @questions.push(new Post post) for post in $(".conversation")
	initializeNewPostListener: =>
		pusher = new Pusher('bffe5352760b25f9b8bd')
		channel = pusher.subscribe(@name)
		channel.bind 'new_post', (data) => @displayNewPost(data, "prepend")
	displayNewPost: (data, insert_type) => 
		# $("#feed_content").first().animate({"top": "200px"})
		conversation = $("#post_template").clone().removeAttr("id").show()
		post = conversation.find(".post")
		post.attr("post_id", data.id)
		post.find("p").text(data.text)
		conversation.css "visibility", "hidden"
		answers_element = post.find(".answers")
		answers = data.question.answers
		for answer, i in answers#@randomize(data.answers)
			if i < (answers.length - 1) then border = "bottom_border" else border = ""
			if answer.correct
				answers_element.append("<h3 correct='true' class='#{border}'>#{answer.text}</h3>")
			else
				answers_element.append("<h3 correct='false' class='#{border}'>#{answer.text}</h3>")
			clone = $("#answer_template").clone().removeAttr('id')
			clone.find("#answer").text(answer.text)
			answers_element.append(clone)
		if insert_type == "prepend"
			$("#feed_content").prepend(conversation)
		else
			conversation.insertBefore("#posts_more")
		conversation.css('visibility','visible').hide().fadeIn('slow')
		@questions.push(new Post conversation)
	showMore: => 
		last_post_id = $(".post.parent:visible").last().attr "post_id"
		$.getJSON "/feeds/#{@id}/more/#{last_post_id}", (posts) => 
			if posts.length > 0
				@displayNewPost(post, "append") for post in posts
			else
				$("#show_more").text("Last Post Reached")
				$(window).off "scroll"
	randomize: (myArray) =>
		i = myArray.length
		return false if i == 0
		while --i
			j = Math.floor( Math.random() * ( i + 1 ) )
			tempi = myArray[i]
			tempj = myArray[j]
			myArray[i] = tempj
			myArray[j] = tempi				


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
			parent = $(e.target).parents(".answer_container").prev("h3")
			@answer("@#{window.feed.name} #{parent.text()}", parent.attr("correct"))
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
			post.toggleClass("active", 50) 
			post.next(".conversation").removeClass("active_next")
			post.prev(".conversation").removeClass("active_prev")	
			post.find(".subsidiary").hide()
			post.find(".answers").hide()
			# @element.find("i").animate({color: "black"}, 0)
		else 
			post.toggleClass("active", 50)
			post.next(".conversation").addClass("active_next")
			post.prev(".conversation").addClass("active_prev")
			post.find(".subsidiary").toggle(50)
			post.find(".answers").toggle(200)	
			# if @correct == true
			# 	@element.find("i").animate({color: "#0B7319"}, 0)
			# else
			# 	@element.find("i").animate({color: "#C43939"}, 0)			
	answer: (text, correct) =>
		answers = @element.find(".answers")
		answers.toggle(200, => answers.remove())
		@tweet(text, correct)
	tweet: (text, correct) =>
		subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
		subsidiary.find("p").text(text)
		subsidiary.find("h5").text(window.feed.user_name)
		loading = @element.find(".loading").text("Tweeting your answer...")
		loading.fadeIn(500, => loading.delay(1000).fadeOut(500, => @element.find(".post").addClass("answered").after(subsidiary.fadeIn(500, => @submit_answer(correct, subsidiary)))))
	submit_answer: (correct, parent) =>
		response = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
		if correct == "true" 
			response.find("p").text("Correct! Booyah!") 
			@correct = true
		else 
			response.find("p").text("Sorry, thats incorrect!")
		response.find("h5").text(window.feed.name)
		loading = @element.find(".loading").text("Thinking...")
		loading.fadeIn(500, => loading.delay(1000).fadeOut(500, => 
				@element.find(".subsidiary").addClass("answered").after(response.fadeIn(500))
				@element.find("i").show()
			)
		)		
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


$ -> window.feed = new Feed# if $("#feed_id").length > 0