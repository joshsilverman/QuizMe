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
	constructor: ->
		@user_name = $("#user_name").val()
		@user_image = $("#user_img").val()
		@name = $("#feed_name").val()
		@id = $("#feed_id").val()
		@conversations = $.parseJSON($("#conversations").val())
		@engagements = $.parseJSON($("#engagements").val())
		@manager = true if $("#manager").length > 0
		@initializeQuestions()
		target = $(".post[post_id=#{$('#post_id').val()}]")
		@scroll_to_question(target) if target.length > 0
		unless @manager
			$(window).on "scroll", => @show_more() if ($(document).height() == $(window).scrollTop() + $(window).height())
			$("#posts_more").on "click", (e) => 
				e.preventDefault()
				@show_more()
		# @initializeNewPostListener()
		mixpanel.track("page_loaded", {"account" : @name, "source": source, "user_name": @user_name})
		mixpanel.track_links(".tweet_button", "no_auth_tweet_click", {"account" : @name, "source": source}) if @user_name == null or @user_name == undefined	
		# $("#gotham").on "click", => mixpanel.track("ad_click", {"client": "Gotham", "account" : @name, "source": source})
	initializeQuestions: => @questions.push(new Post post) for post in $(".conversation")
	scroll_to_question: (target) =>
		target.click()
		target.find("h3[answer_id=#{$('#answer_id').val()}]").click()
		$.scrollTo(target, 500)
	# initializeNewPostListener: =>
	# 	pusher = new Pusher('bffe5352760b25f9b8bd')
	# 	channel = pusher.subscribe(@name)
	# 	channel.bind 'new_post', (data) => @displayNewPost(data, "prepend")
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
	correct_responses: ["That's right!","Correct!","Yes!","That's it!","You got it!","Perfect!"]
	correct_complements: ["Way to go","Keep it up","Nice job","Nice work","Booyah","Nice going","Hear that? That's the sound of AWESOME happening",""]
	incorrect_responses: ["Hmmm, not quite.","Uh oh, that's not it...","Sorry, that's not what we were looking for.","Nope. Time to hit the books (or videos)!","Sorry. Close, but no cigar.","Not quite.","That's not it."]

	constructor: (element) ->
		@answers = []
		@element = $(element)
		@id = @element.find(".post").attr "post_id"
		@question = @element.find(".question").text()
		@answers.push(new Answer answer, @) for answer in @element.find(".answer")
		@element.on "click", (e) => @expand(e)
		@element.find("li").on "click", (e) => @update_engagement_type(e)
		@element.find(".btn").on "click", (e) => 
			if $("#user_name").val() != undefined
				parent = $(e.target).parents(".answer_container").prev("h3")
				@respond_to_question(parent.text(), parent.attr("answer_id"))
		answers = @element.find(".answers")
		answers.accordion({
			collapsible: true, 
			autoHeight: false,
			active: false, 
			icons: false, 
			disabled: true if window.feed.manager
		})		
		answers.on "accordionchange", (e, ui) => 
			if ui.newHeader.length > 0
				$(e.target).find("h3").removeClass("active_next")
				$(ui.newHeader).nextAll('h3:first').toggleClass("active_next")
			else
				$(e.target).find("h3").removeClass("active_next")
	expand: (e) =>
		if window.feed.manager
			@open_reply_modal(e)
			return
		# console.log e.target
		# window.post = $(e.target)
		# if $(e.target).hasClass "label"
		# 	@link_post(e)
		# 	return
		# if $(e.target).parents('.post').children('#classify').children('.btn-group').children('.dropdown-toggle').html() == "Reply"# or $(e.target).hasClass("reply")
			# @open_reply_modal(e)
			# return
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
				subsidiary.find("p").text("@#{window.feed.name} #{text} #{e.url}")
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
		tweet = ''
		$("#respond_modal").dialog
			title: "Reply to #{username}"
			width: 521
			modal: true
		$("button.btn.correct, button.btn.incorrect, #tweet.btn.btn-info").off
		$("button.btn.correct").click ()=>
			correct = true
			response = @correct_responses[Math.floor (Math.random() * @correct_responses.length )]
			complement = @correct_complements[Math.floor (Math.random() * @correct_complements.length )]
			tweet = "#{response} #{complement}"
			$(".modal_body textarea").html("@#{username} #{tweet}")
		$("button.btn.incorrect").click ()=>
			correct = false
			response = @incorrect_responses[Math.floor (Math.random() * @incorrect_responses.length )]
			tweet = response
			$(".modal_body textarea").html("@#{username} #{tweet}")
		$("#tweet.btn.btn-info").click ()=>
			params =
			"asker_id" : window.feed.id
			"post_id" : @id
			"correct" : correct
			"tweet" : tweet
			"username" : username
			# "text" : text #This will eventually be any custom text (?)
			$.ajax '/tweet',
				type: 'POST'
				data: params
				success: (e) =>
					console.log e
					$("#respond_modal").dialog('close')
		convo =  window.feed.conversations[post.attr('post_id')]
		console.log convo
		$('.modal_conversation_history > .conversation').html('')

		subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
		subsidiary.find("p").text("#{p['text']}") 
		subsidiary.find("h5").text("#{convo['users'][p['user_id']]['twi_screen_name']}")
		image = convo['users'][p['user_id']]['twi_profile_img_url']
		subsidiary.find("img").attr("src", image) unless image == null
		#subsidiary.addClass("answered") if i < (interaction[0].posts.length - 1)
		$('.modal_conversation_history').find(".conversation").append(subsidiary.show())

		html = "<div class='subsidiary post'>"
		$.each convo['answers'], (i, a) ->
			console.log a
			html+= "<div class='answers rounded border'><h3 style='#{'color: green;' if a['correct']}'>#{a['text']}</h3></div>"
		html += "</div>"
		$('.modal_conversation_history').find(".conversation").append(html)
		$.each convo['posts'], (i, p) ->
			console.log p
			subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
			subsidiary.find("p").text("#{p['text']}") 
			subsidiary.find("h5").text("#{convo['users'][p['user_id']]['twi_screen_name']}")
			image = convo['users'][p['user_id']]['twi_profile_img_url']
			subsidiary.find("img").attr("src", image) unless image == null
			#subsidiary.addClass("answered") if i < (interaction[0].posts.length - 1)
			$('.modal_conversation_history').find(".conversation").append(subsidiary.show())


	link_post: (event) =>
		console.log 'LINK POST'
		console.log event
		window.post = event
		post = event.parents().eq('.post').children('.content').html()
		$("#link_post_modal").dialog
			title: "Link Post"
			width: 521
			height: 600
			position: "center bottom"
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
					console.log e
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


$ -> window.feed = new Feed if $("#feed").length > 0
