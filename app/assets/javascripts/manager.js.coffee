class @Manager extends @Feed
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
	active_tags: []
	
	constructor: ->
		@correct_complements = $.parseJSON($("#correct_complements").val())
		@correct_responses = $.parseJSON($("#correct_responses").val())

		@user_name = $("#user_name").val()
		@user_image = $("#user_img").val()
		@name = $("#feed_name").val()
		@id = $("#feed_id").val()
		@correct = $("#correct").val()
		@conversations = $.parseJSON($("#conversations").val())
		@engagements = window.engagements = $.parseJSON($("#engagements").val())
		@initialize_posts($(".conversation"))
		@initialize_ask()

		$('.best_in_place').on "ajax:success", ->
			alert('broken success callback - this does not fire')

		$("#respond_modal").on "hidden", => 
			$("#respond_modal").find("textarea").val("")
			$("#respond_modal").find(".correct").removeClass("active")
			$("#respond_modal").find(".incorrect").removeClass("active")
			$(".response_message").hide()
			$("#respond_modal #tweet").removeClass("disabled")
			$(".response_container .character_count").text(140)
			$(".response_container .character_count").css "color", "#333"
			document.activeElement.blur()
			
		$("#unlink_post").on "click", => 
			$("#unlink_post").button("loading")
			window.current_post.unlink_post()
		$("#retweet_question").on "click", (e) => 
			e.preventDefault()
			$.grep(@posts, (p) -> return p.id == $(e.target).attr('post_id'))[0].retweet()
		$(".mark_ugc").on "click", (e) => 
			$.grep(@posts, (p) -> return p.id == $(e.target).parents(".post").first().attr 'post_id')[0].mark_ugc()
		$(".tag_post").on "click", (e) => 
			$.grep(@posts, (p) -> return p.id == $(e.target).parents(".post").first().attr 'post_id')[0].toggle_tag($(e.target).attr("tag_name"), $(e.target))
		$(".tag_select input").on "change", (e) => 
			if $(e.target).is(":checked") then @active_tags.push $(e.target).parent().text().trim() else @active_tags.remove $(e.target).parent().text().trim()
			if @active_tags.length == 0
				$.each @posts, (i, p) => p.element.fadeIn()
			else
				$.each @posts, (i, p) => p.element.fadeOut()
				$.each @active_tags, (i, t) => $(".#{t}").fadeIn()
		$("#add_tag .btn").on "click", (e) => @add_tag(e)

		@hotkeys = new Hotkeys

	initialize_posts: (posts) => 
		$.each posts, (i, post) =>
			id = parseInt $(post).children('.post').attr('post_id')
			active_record = window.engagements[id]
			@posts.push(new Post post, active_record)

	initialize_ask: => 
		ask_element = $("#send_tweet .question_container")
		textarea = ask_element.find("textarea")
		count = ask_element.find(".character_count")
		button = ask_element.find(".tweet_button")
		button.on "click", => 
			if (140 - textarea.val().length) > 0
				button.button("loading")
				params = 
					"text" : textarea.val()
					"asker_id" : @id
				$.ajax '/manager_post',
					type: 'POST'
					data: params
					success: (e) =>
						textarea.hide()
						button.button("reset")
						# ask_element.find(".post_url").attr "href", "http://twitter.com/#{@user_name}/status/#{e}"
						ask_element.removeClass("focus").addClass("blur")
						ask_element.find(".ask_success").fadeIn(250)
					error: =>
						textarea.hide()
						button.button("reset")
						ask_element.removeClass("focus").addClass("blur")
						ask_element.find(".ask_success").text("Sorry, something went wrong!").fadeIn(250)
		textarea.on "focus", => 
			ask_element.removeClass("blur").addClass("focus")
			# if textarea.val() == ""
				# textarea.val("@#{@name} ")
			update_character_count()
		textarea.on "blur", => 
			if textarea.val() == "@#{@name} " or textarea.val() == ""
				textarea.val("")
				# ask_element.removeClass("focus").addClass("blur")
			update_character_count()
		textarea.on "keydown", => update_character_count()
		$(".ask_again").on "click", =>
			ask_element.find(".ask_success").hide()
			textarea.val("").fadeIn(250)
		update_character_count = ->
			text = 140 - textarea.val().length
			count.text(text)
			if text < 0
				button.addClass("disabled")
			else if text < 10
				count.css "color", "red"
				button.removeClass("disabled")
			else
				count.css "color", "#333"
				button.removeClass("disabled")

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

	add_tag: (e) =>
		$.ajax "/posts/add_tag",
			type: 'POST',
			data: 
				"post_id" : @id,
				"tag_name" : name
			success: (status) =>
				@update_feedback_tag_status(element, status) if element		


class Post
	constructor: (element, active_record) ->
		@answers = []
		@element = $(element)
		@id = @element.find(".post").attr "post_id"
		@active_record = active_record

		@question = @element.find(".question").text()
		@answers.push(new Answer answer, @) for answer in @element.find(".answer")

		@element.on "click", (e) => 
			unless $(e.target).parents("#respond_modal").length > 0
				$('.conversation').removeClass 'active'
				$(e.target).closest('.conversation').addClass 'active'

		@element.find(".tweet_button").on "click", (e) => 
			if $("#user_name").val() != undefined
				parent = $(e.target).parents(".answer_container").prev("h3")
				@respond_to_question(parent.text(), parent.attr("answer_id"))

		if window.engagements[@id]
			@asker_id = window.engagements[@id]['in_reply_to_user_id']

		@element.find(".show_move").on "click", =>
			@element.find(".show_move").hide()
			@element.find(".move").show()

		@element.find(".link_post, .open").on "click", @expand

		@element.find(".quick-reply-yes").on "click", => @quick_reply true
		@element.find(".quick-reply-no").on "click", => @quick_reply false
		@element.find(".quick-reply-tell").on "click", => @quick_reply false, true

		@element.find(".script").on "click", (e) => @scripted_response($(e.target).attr("script_text"))

		@element.find(".nudge").on "click", (e) => @nudge($(e.target).attr("nudge_id"))

		answers = @element.find(".answers")
		answers.accordion({
			collapsible: true, 
			autoHeight: false,
			active: false, 
			icons: false, 
			disabled: true
		})

		# @element.find('.btn-hide, .btn-flag').on "ajax:success", -> 
		# 	puts $(this)
		# 	$(this).parents(".conversation").toggleClass "dim"

	expand: (e) =>
		if $(e.target).hasClass("link_post")
			@link_post($(e.target))
			return
		else if $(e.target).hasClass "add_question"
			post = $(e.target).parents(".post")
			window.feed.post_question(
				post.find(".content p").text().replace(/\s+/g, ' ').replace(/@[a-zA-Z0-9]* /, "").trim(), 
				post.attr("post_id")
			)
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

	open_reply_modal: (event = nil) =>
		post = @element.find('.post')
		username = post.find('h5 span').html()
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

		$("#respond_modal").modal()
		if post.attr("interaction_type") != "4"
			text = "@#{username} "
			textarea.focus()
			textarea.val(text)
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
				"asker_id" : @asker_id
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
					post.parents(".conversation").css("opacity", 0.8)
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
		$.each convo['posts'], (i, p) ->
			subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
			subsidiary.find("p").text("#{p['text']}") 
			subsidiary.find("h5").text("#{convo['users'][p['user_id']]['twi_screen_name']}")
			image = convo['users'][p['user_id']]['twi_profile_img_url']
			subsidiary.find("img").attr("src", image) unless image == null
			$('.modal_conversation_history').find(".conversation").append(subsidiary.show())
			if i == 0 and convo['answers'].length > 0
				html = "<div class='subsidiary post'>"
				$.each convo['answers'], (j, a) ->
					html+= "<div class='answers rounded border'><h3 style='#{'color: green;' if a['correct']}'>#{a['text']}</h3></div>"
				html += "</div>"
				$('.modal_conversation_history').find(".conversation").append(html)
		textarea.focus()

	quick_reply: (correct, tell = false) =>
		event.stopPropagation()
		@correct = correct
		post = @element.find('.post')
		parent_index = window.feed.conversations[@id]['posts'].length - 1
		parent_post = window.feed.conversations[@id]['posts'][parent_index]

		publication_id = null
		publication_id = parent_post['publication_id'] unless parent_post == undefined
		params =
			"interaction_type" : post.attr "interaction_type"
			"asker_id" : @asker_id
			"in_reply_to_post_id" : @id
			"in_reply_to_user_id" : window.feed.engagements[@id]['user_id']
			# "message" : tweet
			"username" : post.find('h5 span').html()
			"correct" : @correct
			"tell" : tell #just tell the correct answer
			"publication_id" : publication_id

		if post.closest(".conversation").hasClass "dim"
			return unless confirm("Reply again to this conversaion?")
		$.ajax '/manager_response',
			type: 'POST'
			data: params
			error: (e) => console.log "ajax error tweeting response"
			success: (e) =>
				if e == false
					console.log "twitter failed to send message"
				else
					post.closest(".conversation").addClass "dim"
					console.log "succeeded in sending message"
					# $(".post[post_id=#{@id}]").children('.icon-share-alt').show()

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
		if $.trim(event.text()) == "unlink"
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

	toggle_tag: (name, element = null) =>
		$.ajax "/posts/toggle_tag",
			type: 'POST',
			data: 
				"post_id" : @id,
				"tag_name" : name
			success: (status) =>
				@update_feedback_tag_status(element, status) if element

	update_feedback_tag_status: (element, status) => if status == true then element.css("font-weight", "bold") else element.css("font-weight", "normal")

	mark_ugc: =>
		$.ajax "/posts/mark_ugc",
			type: 'POST',
			data: "post_id" : @id

	retweet: =>
		$("#retweet_question").button("loading")

		$.ajax "/posts/retweet",
			type: 'POST',
			data:
				"post_id" : @id
				"asker_id" : @asker_id
			complete: => 
				$("#retweet_question_modal").modal('hide')	
				$('#retweet_question').button('reset')
			success: => @element.toggleClass "dim"

	scripted_response: (script) =>
		# event.stopPropagation()
		post = @element.find('.post')
		parent_index = window.feed.conversations[@id]['posts'].length - 1
		parent_post = window.feed.conversations[@id]['posts'][parent_index]

		publication_id = null
		publication_id = parent_post['publication_id'] unless parent_post == undefined

		params =
			"interaction_type" : post.attr "interaction_type"
			"asker_id" : @asker_id
			"in_reply_to_post_id" : @id
			"in_reply_to_user_id" : window.feed.engagements[@id]['user_id']
			"message" : script
			"username" : post.find('h5 span').html()

		if post.closest(".conversation").hasClass "dim"
			return unless confirm("Reply again to this conversaion?")
		$.ajax '/manager_response',
			type: 'POST'
			data: params
			error: (e) => console.log "ajax error tweeting response"
			success: (e) =>
				if e == false
					console.log "twitter failed to send message"
				else
					post.closest(".conversation").addClass "dim"
					console.log "succeeded in sending message"
					# $(".post[post_id=#{@id}]").children('.icon-share-alt').show()		

	nudge: (nudge_type_id) => 
		$.ajax "/askers/nudge",
			type: 'POST',
			data:
				"user_id": window.feed.engagements[@id]['user_id']
				"nudge_type_id": nudge_type_id
				"asker_id" : @asker_id
			# complete: => 
				# $("#retweet_question_modal").modal('hide')	
				# $('#retweet_question').button('reset')
			success: => @element.toggleClass "dim"	

class Hotkeys
	constructor: ->
		$('.conversation').first().addClass 'active'
		$(window).keypress (e) =>
			return if e.target and (e.target.tagName == "TEXTAREA" or e.target.tagName == "INPUT")
			active_post = @_active_post()
			switch e.keyCode
				when 106 then @prev()
				when 107 then @next()
				when 111 then @open(e)

				when 32 then @accept_autocorrect(e, active_post)
				when 110 then active_post.quick_reply false if active_post #no
				when 116 then active_post.quick_reply false, true if active_post #yes
				when 121 then active_post.quick_reply true if active_post #yes

				when 102 then $("#best_in_place_post_#{active_post.id}_spam").trigger('click') if active_post
				when 104 then @toggle_hide active_post
				when 114 then active_post.retweet() if active_post

				when 113 then window.feed.post_question(active_post.active_record.text, active_post.id)
	accept_autocorrect: (e, active_post) ->
		e.preventDefault()
		if active_post
			autocorrect = active_post.active_record.autocorrect
			puts autocorrect
			return if autocorrect == null

			active_post.quick_reply autocorrect
			# @prev()

	toggle_hide: (post_obj) ->
		$("#best_in_place_post_#{post_obj.id}_requires_action").trigger('click') if post_obj
		# post = $('.conversation.active .post')
		# post.parents(".conversation").toggleClass "dim"

	open: (e) ->
		post_obj = @_active_post()

		# mimic event in calling expand
		e.preventDefault()
		post = $('.conversation.active .post')
		post_obj.expand({target: post}) if post_obj

	prev: ->
		current_conv = $('.conversation.active')
		prev_conv = current_conv.next('.conversation') #confusing because next in time is reverse in sequence
		prev_conv = $('#posts .conversation').first() if prev_conv.length == 0

		current_conv.removeClass 'active'
		prev_conv.addClass 'active'
		@_isScrolledIntoView prev_conv

	next: ->
		current_conv = $('.conversation.active')
		next_conv = current_conv.prev('.conversation') #confusing because next in time is reverse in sequence
		next_conv = $('#posts .conversation').last() if next_conv.length == 0

		current_conv.removeClass 'active'
		next_conv.addClass 'active'
		@_isScrolledIntoView next_conv

	_isScrolledIntoView: (elem) ->
		docViewTop = $(window).scrollTop()
		docViewBottom = docViewTop + $(window).height()

		elemTop = $(elem).offset().top
		elemBottom = elemTop + $(elem).height()

		visible = ((elemBottom >= docViewTop) && (elemTop <= docViewBottom) && (elemBottom <= docViewBottom) &&  (elemTop >= docViewTop))
		unless visible
			$('html, body').animate({
				scrollTop: elem.offset().top - 150
			}, 1);

	_active_post: (e) ->
		post = $('.conversation.active .post')
		return if post.length == 0

		post_id = post.attr "post_id"
		post_obj = null
		$.each feed.posts, (i, p) -> post_obj = p if p.id == post_id
		post_obj

$ -> window.feed = new Manager if $("#manager").length > 0 or $("#tags").length > 0