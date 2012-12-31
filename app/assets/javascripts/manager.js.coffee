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
	correct_responses: []
	correct_complements: []
	# incorrect_responses: ["Hmmm, not quite.","Uh oh, that's not it...","Sorry, that's not what we were looking for.","Nope. Time to hit the books!","Sorry. Close, but no cigar.","Not quite.","That's not it."]	
	incorrect_responses: ["Hmmm, not quite.","Uh oh, that's not it...","Sorry, that's not what we were looking for.","Nope. Time to hit the books!","Sorry. Close, but no cigar.","Not quite.","That's not it."]	
	
	constructor: ->
		@correct_complements = $.parseJSON($("#correct_complements").val())
		@correct_responses = $.parseJSON($("#correct_responses").val())

		@user_name = $("#user_name").val()
		@user_image = $("#user_img").val()
		@name = $("#feed_name").val()
		@id = $("#feed_id").val()
		@correct = $("#correct").val()
		@conversations = $.parseJSON($("#conversations").val())
		@engagements = $.parseJSON($("#engagements").val())
		@initialize_posts($(".conversation"))
		@initialize_character_count()
		$('.best_in_place').on "ajax:success", ->
			if $(this).data("type") == "checkbox"
				conversation = $(this).parents(".conversation")
				if conversation.css("opacity") == "1" then conversation.css("opacity", 0.8) else conversation.css("opacity", 1)
		$("#respond_modal").on "hidden", => 
			$("#respond_modal").find("textarea").val("")
			$("#respond_modal").find(".correct").removeClass("active")
			$("#respond_modal").find(".incorrect").removeClass("active")
			$(".response_message").hide()
			$("#respond_modal #tweet").removeClass("disabled")
			$(".response_container .character_count").text(140)
			$(".response_container .character_count").css "color", "#333"
		$("#unlink_post").on "click", => 
			$("#unlink_post").button("loading")
			window.current_post.unlink_post()
		$("#retweet_question").on "click", (e) => 
			e.preventDefault()
			$.grep(@posts, (p) -> return p.id == $(e.target).attr('post_id'))[0].retweet(@id)
		$(".mark_ugc").on "click", (e) => 
			$.grep(@posts, (p) -> return p.id == $(e.target).parents(".post").first().attr 'post_id')[0].mark_ugc()

	initialize_posts: (posts) => @posts.push(new Post post) for post in posts		

	initialize_character_count: => 
		response_container = $(".response_container")
		textarea = response_container.find("textarea")
		count = response_container.find(".character_count")
		button = $("#respond_modal #tweet")
		textarea.on "keydown", => update_character_count()
		update_character_count = ->
			text = 140 - textarea.val().length
			count.text(text)
			if text < 0
				button.addClass("disabled")
				count.css "color", "red"
			else if text < 10
				count.css "font-weight", "bold"
				button.removeClass("disabled")
				count.css "color", "#333"
			else
				count.css "font-weight", "normal"
				count.css "color", "#333"
				button.removeClass("disabled")

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
		@element.on "click", (e) => @expand(e) unless $(e.target).parents("#respond_modal").length > 0
		@element.find(".tweet_button").on "click", (e) => 
			if $("#user_name").val() != undefined
				parent = $(e.target).parents(".answer_container").prev("h3")
				@respond_to_question(parent.text(), parent.attr("answer_id"))

		@element.find(".show_move").on "click", =>
			@element.find(".show_move").hide()
			@element.find(".move").show()

		@element.find(".quick-reply-yes").on "click", => @quick_reply true
		@element.find(".quick-reply-no").on "click", => @quick_reply false

		answers = @element.find(".answers")
		answers.accordion({
			collapsible: true, 
			autoHeight: false,
			active: false, 
			icons: false, 
			disabled: true
		})	

	expand: (e) =>
		if $(e.target).hasClass("link_post")
			@link_post($(e.target))
			return
		else if $(e.target).hasClass "mark_ugc"
			$(e.target).text("marked ugc")
		else if $(e.target).hasClass "retweet"
			$("#retweet_question_modal .modal-body").hide()
			$("#retweet_question_modal").find("#retweet_question").attr "post_id", @id
			$("#retweet_question_modal").modal()			
		else if $(e.target).parents("#link_post_modal").length > 0 or $(e.target).is("a span") or $(e.target).hasClass("show_move")
			return
		else
			@open_reply_modal(e) 
			return		

	open_reply_modal: (event) =>
		post = $(event.target)
		post = post.parents(".post") unless post.hasClass "post"
		window.post = post
		username = post.find('h5').html()
		correct = null
		tweet = ''
		parent_index = window.feed.conversations[@id]['posts'].length - 1
		parent_post = window.feed.conversations[@id]['posts'][parent_index]

		textarea = $("#respond_modal").find("textarea")
		if parent_post == undefined		
			publication_id = null
		else
			publication_id = parent_post['publication_id'] 
			$("#respond_modal").find(".correct").show()		
			$("#respond_modal").find(".incorrect").show()			

		if post.attr("interaction_type") != "4"
			text = "@#{username} "
			textarea.val(text) 
			textarea.focus()
		$("#respond_modal").modal()
		$("button.btn.correct, button.btn.incorrect, #tweet").off()
		$("button.btn.correct").on 'click', () =>
			correct = true
			response = window.feed.correct_responses[Math.floor (Math.random() * window.feed.correct_responses.length )]
			complement = window.feed.correct_complements[Math.floor (Math.random() * window.feed.correct_complements.length )]
			if post.attr("interaction_type") != "4"
				$("#respond_modal textarea").val("@#{username} #{response} #{complement}")
			else
				$("#respond_modal textarea").val("#{response} #{complement}")
		$("button.btn.incorrect").on 'click', ()=>
			correct = false
			if post.attr("interaction_type") != "4"
				$("#respond_modal textarea").val("@#{username} #{window.feed.incorrect_responses[Math.floor (Math.random() * window.feed.incorrect_responses.length )]}")
			else
				$("#respond_modal textarea").val("#{window.feed.incorrect_responses[Math.floor (Math.random() * window.feed.incorrect_responses.length )]}")
		$("#tweet").on 'click', () =>
			tweet = $("#respond_modal").find("textarea").val()
			return if tweet == ""
			$("#tweet").button("loading")
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
				error: (e) => 
					$("#tweet").button('reset')
					$("#respond_modal").find(".correct").removeClass("active")
					$("#respond_modal").find(".incorrect").removeClass("active")					
				success: (e) =>
					if e == false
						message = $(".response_message")
						message.text("Failed to send message!")
						message.show()
					else
						$(".post[post_id=#{@id}]").children('#classify').hide()
						$(".post[post_id=#{@id}]").children('.icon-share-alt').show()
						$("#respond_modal").modal('hide')
					$("#tweet").button('reset')
		convo =  window.feed.conversations[post.attr('post_id')]
		$('.modal_conversation_history > .conversation').html('')
		user_post = window.feed.engagements[@id]
		subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
		subsidiary.find("p").text("#{user_post['text']}") 
		subsidiary.find("h5").text("#{convo['users'][user_post['user_id']]['twi_screen_name']}")
		image = convo['users'][user_post['user_id']]['twi_profile_img_url']
		subsidiary.find("img").attr("src", image) unless image == null
		$('.modal_conversation_history').find(".conversation").append(subsidiary.show())
		$.each convo['posts'], (i, p) ->
			console.log i, p
			subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
			subsidiary.find("p").text("#{p['text']}") 
			subsidiary.find("h5").text("#{convo['users'][p['user_id']]['twi_screen_name']}")
			image = convo['users'][p['user_id']]['twi_profile_img_url']
			subsidiary.find("img").attr("src", image) unless image == null
			$('.modal_conversation_history').find(".conversation").append(subsidiary.show())
			if i == 0
				html = "<div class='subsidiary post'>"
				$.each convo['answers'], (j, a) ->
					html+= "<div class='answers rounded border'><h3 style='#{'color: green;' if a['correct']}'>#{a['text']}</h3></div>"
				html += "</div>"
				$('.modal_conversation_history').find(".conversation").append(html)
		textarea.focus()

	quick_reply: (correct) =>
		event.stopPropagation()
		@correct = correct
		post = $(event.target)
		post = post.parents(".post") unless post.hasClass "post"
		parent_index = window.feed.conversations[@id]['posts'].length - 1
		parent_post = window.feed.conversations[@id]['posts'][parent_index]

		publication_id = null
		publication_id = parent_post['publication_id'] unless parent_post == undefined

		if correct == true
			response = window.feed.correct_responses[Math.floor (Math.random() * window.feed.correct_responses.length)]
			complement = window.feed.correct_complements[Math.floor (Math.random() * window.feed.correct_complements.length)]
			tweet = "#{response} #{complement}"
		else
			tweet = "#{window.feed.incorrect_responses[Math.floor (Math.random() * window.feed.incorrect_responses.length )]}"

		params =
			"interaction_type" : post.attr "interaction_type"
			"asker_id" : window.feed.id
			"in_reply_to_post_id" : @id
			"in_reply_to_user_id" : window.feed.engagements[@id]['user_id']
			"message" : tweet
			"username" : post.find('h5').html()
			"correct" : @correct
			"publication_id" : publication_id

		$.ajax '/manager_response',
			type: 'POST'
			data: params
			error: (e) => console.log "ajax error tweeting response"
			success: (e) =>
				if e == false
					console.log "twitter failed to send message"
				else
					console.log "succeeded in sending message"
					$(".post[post_id=#{@id}]").children('.icon-share-alt').show()

	unlink_post: =>
		params =
			"link_to_pub_id" : 0
			"post_id" : @id
		$.ajax '/link_to_post',
			type: 'POST'
			data: params
			success: (e) =>
				@element.find('.link_post').text("link")
				window.feed.conversations[@id] = {"posts":[]}
				$("#unlink").button('reset')
				$("#confirm").modal('hide')

	link_post: (event) =>
		window.post = event
		if event.text() == "unlink"
			window.current_post = @
			$("#confirm").modal()
		else
			post = event.parents('.post').find('.content')
			$('#link_post_modal').modal(
				"keyboard" : true
			)
			content = $("#link_post_modal .parent_post .content ")
			content.find("p").text(post.find("p").text())
			content.find("h5").text(post.find("h5").text())
			content.find("img").attr("src", post.find("img").attr("src"))
			$("#link").off "click"
			$("#link").on "click", =>
				params =
					"link_to_pub_id" : $("input:checked").val()
					"post_id" : @id
				$.ajax '/link_to_post',
					type: 'POST'
					data: params
					success: (e) =>
						window.feed.conversations[@id] = {"posts":[]}
						window.feed.conversations[@id]['posts'].push("publication_id" : $("input:checked").val())
						$("#link_post_modal").modal('hide')
						window.post.text("unlink")

	mark_ugc: =>
		$.ajax "/posts/mark_ugc",
			type: 'POST',
			data: "post_id" : @id

	retweet: (asker_id) =>
		$("#retweet_question").button("loading")

		$.ajax "/posts/retweet",
			type: 'POST',
			data:
				"post_id" : @id
				"asker_id" : asker_id
			complete: => 
				$("#retweet_question_modal").modal('hide')	
				$('#retweet_question').button('reset')

$ -> window.feed = new Feed if $("#manager").length > 0