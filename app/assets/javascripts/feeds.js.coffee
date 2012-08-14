class Feed
	id: null
	name: null 
	questions: []
	answered: 0
	constructor: ->
		$(".conversation").on "click", (e) => 
			return if $(e.target).parent(".answers").length > 0 or $(e.target).hasClass("tweet") or $(e.target).parent(".tweet").length > 0 or $(e.target).hasClass("btn")
			if $(e.target).hasClass("conversation") then post = $(e.target) else post = $(e.target).closest(".conversation")
			if post.hasClass("active")
				post.toggleClass("active", 50) 
				post.next(".conversation").removeClass("active_next")
				post.prev(".conversation").removeClass("active_prev")	
				post.find(".subsidiary").hide()
				post.find(".answers").hide()
			else 
				post.toggleClass("active", 50)
				post.next(".conversation").addClass("active_next")
				post.prev(".conversation").addClass("active_prev")
				answers = post.find(".answers")
				answers.accordion({
					collapsible: true, 
					autoHeight: false,
					active: false, 
					icons: false
				})
				post.find(".subsidiary").show()
				answers.toggle(200)
		@name = $("#feed_name").val()
		@id = $("#feed_id").val()
		@initializeQuestions()
		# @initializeNewPostListener()
		# $("#show_more").on "click", => @showMore()
		# $(window).on "scroll", => @showMore() if ($(document).height() == $(window).scrollTop() + $(window).height())
		# mixpanel.track("page_loaded", {"account" : @name, "source": source})
		# $("#gotham").on "click", => mixpanel.track("ad_click", {"client": "Gotham", "account" : @name, "source": source})
	initializeQuestions: => @questions.push(new Post post) for post in $(".conversation")
	initializeNewPostListener: =>
		pusher = new Pusher('bffe5352760b25f9b8bd')
		channel = pusher.subscribe(@name)
		channel.bind 'new_post', (data) => @displayNewPost(data, "prepend")
	displayNewPost: (data, insertType) => 
		# $("#feed_content").first().animate({"top": "200px"})
		post = $("#post_template").clone().removeAttr("id").addClass("post").attr("post_id", data.id)
		post.find(".header p").text("#{@name} (3m ago):")
		post.find(".question p").text(data.text)
		post.css "visibility", "hidden"
		answers = post.find(".answers")
		for answer in data.question.answers#@randomize(data.answers)
			if answer.correct
				answers.append("<div class='answer correct'>#{answer.text}</div>")
			else
				answers.append("<div class='answer'>#{answer.text}</div>")
		if insertType == "prepend"
			$("#feed_content").prepend(post)
		else
			post.insertBefore("#show_more")
		post.css('visibility','visible').hide().fadeIn('slow')
		@questions.push(new Post post)
	showMore: => 
		lastPostID = $(".post").last().attr "post_id"
		$.getJSON "/feeds/#{@id}/more/#{lastPostID}", (posts) => 
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
	answers: []
	constructor: (element) ->
		@answers = []
		@element = $(element)
		@id = @element.find(".post").attr "post_id"
		@question = @element.find(".question").text()
		@answers.push(new Answer answer, @) for answer in @element.find(".answer")
		@element.find(".btn").on "click", (e) => 
			parent = $(e.target).parents(".answer_container").prev("h3")
			@answer("@#{window.feed.name} #{parent.text()}", parent.attr("correct"))
	answer: (text, correct) =>
		answers = @element.find(".answers")
		answers.toggle(200, => answers.remove())
		@tweet(text, correct)
	tweet: (text, correct) =>
		subsidiary = $("#post_template").clone().addClass("subsidiary").removeAttr("id")
		subsidiary.find("p").text(text)
		loading = @element.find(".loading")
		loading.fadeIn(500, => loading.delay(1000).fadeOut(500, => @element.find(".post").addClass("answered").after(subsidiary.fadeIn(500, => @submit_answer(correct, subsidiary)))))
	submit_answer: (correct, parent) =>
		response = $("#post_template").clone().addClass("subsidiary").removeAttr("id")
		if correct == "true" then response.find("p").text("Correct! Booyah!") else response.find("p").text("Sorry, thats incorrect!")
		loading = @element.find(".loading")
		loading.fadeIn(500, => loading.delay(1000).fadeOut(500, => @element.find(".subsidiary").addClass("answered").after(response.fadeIn(500))))		
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