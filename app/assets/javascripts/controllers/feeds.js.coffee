class @Feed
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
		@user_name = $("#user_name").val()
		@user_image = $("#user_img").val()
		@name = $("#feed_name").val()
		@id = $("#feed_id").val()
		@requested_publication_id = $("#requested_publication").val()
		@answered_count = 0

		@initialize_posts($(".conversation"))
		@initialize_infinite_scroll()
		@initialize_tooltips()
		@initialize_fix_position_listener() unless $(".index").length > 0

		$('.nav-tabs .activity').on 'click', => 
			return if $(".tab-content .activity").find(".tab-pane").length > 0
			$.get '/users/activity_feed', (data) =>
				$(".tab-content .activity").empty().append(data)
				$(".timeago").timeago()
				$(".activity img").tooltip()

		$(".activity img").tooltip()
		$(".timeago").timeago()

		$("#retweet_question").on "click", (e) => 
			e.preventDefault()
			$("#retweet_question").button("loading")
			@retweet($(e.target))
		mixpanel.track("page_loaded", {"account" : @name, "source": source, "user_name": @user_name, "type": "feed"})
		mixpanel.track_links(".related_feed", "clicked_related", {"account" : @name, "source": source})
		
		$(".profile").on "click", => mixpanel.track("profile click", {"account" : @name, "source": source, "type": "activity"})

		@filtered = $('.tab-content .activity').length > 0

	initialize_fix_position_listener: =>
		offset = 204
		$(window).on "scroll", => 
			if $(window).scrollTop() >= offset
				$("#left_column_container").css("position", "fixed").css("top", "15px")
			else
				$("#left_column_container").css("position", "").css("top", "auto")

	initialize_infinite_scroll: =>
		window.appending = false
		$(window).on "scroll", => 
			return if window.appending
			if ($(window).scrollTop() >= $(document).height() - $(window).height() - 1)
				window.appending = true
				@show_more() 
		$("#posts_more").on "click", (e) => 
			e.preventDefault()
			@show_more()	

	initialize_tooltips: =>
		$(".interaction").tooltip()
		$("#directory img").tooltip()

	initialize_posts: (posts) => @posts.push(new Post post) for post in posts

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

	show_more: => 
		last_post_id = $(".post.parent:visible").last().attr "post_id"
		if last_post_id == undefined
			$("#posts_more").text("Last Post Reached")
			$(window).off "scroll"		
			return 
		else
			$.ajax
				url: "/feeds/#{@id}/more/#{last_post_id}?filtered=#{@filtered}",
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
		@element.tappable (e) => @expand() unless $(e.target).parents('.after_answer').length > 0 or $(e.target).is("input") or $(e.target).hasClass("asker_link") or $(e.target).parents(".ui-dialog").length > 0 or $(e.target).parent(".answers").length > 0 or $(e.target).hasClass("answer_controls") or $(e.target).hasClass("tweet") or $(e.target).parent(".tweet").length > 0 or $(e.target).hasClass("btn") or $(e.target).hasClass("retweet") or $(e.target).hasClass("answer_link") or $(e.target).parent(".asker_link").length > 0 or $(e.target).parent(".question_via").length > 0
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
			else
				element = $(e.target)
				window.location.replace("/users/auth/twitter?answer_id=#{element.attr('answer_id')}&feed_id=#{element.attr('feed_id')}&post_id=#{element.attr('post_id')}&use_authorize=false")
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

	expand: (duration = 200) =>
		if @element.hasClass("active")
			@expanded = false
			@element.find(".expand").text("Answer")
			@element.find(".subsidiaries, .loading, .answers").hide()
			@element.find(".subsidiaries, .loading, .answers").hide()
			if $(window).width() < 400 then @element.removeClass("active") else @element.toggleClass("active", duration)
			@element.next(".conversation").removeClass("active_next")
			@element.prev(".conversation").removeClass("active_prev")	
			@element.find(".answered_indicator").css("opacity", ".4")
		else 
			# Mobile specific improvements
			@expanded = true
			@element.find(".retweet").css("visibility", "visible") if window.feed.user_name != undefined
			@element.find(".expand").text("Collapse")
			@element.find(".answered_indicator").css("opacity", ".6")
			if $(window).width() < 400 
				@element.find(".answers").show()
				@element.find(".subsidiaries").show()
				@element.addClass("active")
				@element.next(".conversation").addClass("active_next")
				@element.prev(".conversation").addClass("active_prev")
			else
				@element.find(".answers").slideToggle(duration)
				@element.find(".subsidiaries").slideToggle(duration, => 
					@element.toggleClass("active", duration)
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
			"publication_id" : @id
			"answer_id" : answer_id
		$.ajax '/respond_to_question',
			type: 'POST'
			data: params
			success: (e) => 
				window.feed.answered += 1
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
								first_post.next().fadeIn(500, => 
									@show_activity()
									if window.feed.requested_publication_id == @id
										@element.find('.feedback .btn').on 'click', (e) =>
											element = $(e.target)
											e.stopImmediatePropagation()
											@submit_question_feedback(element)
										conversation.find(".after_answer.feedback").fadeIn(500)
									else if conversation.find('#request_email').val() == 'true'
										@element.find('.request_email .btn').on 'click', (e) => @submit_email($(e.target))
										conversation.find(".after_answer.request_email").fadeIn(500, => @element.find('#email_input').focus())
								)
								icon.fadeIn(250)
							)
						)
					)
				)
			error: => loading.text("Something went wrong, sorry!").delay(2000).fadeOut()

	show_activity: =>
		if @element.find(".activity_container:visible").length > 0
			@element.find(".user_answered").fadeIn(500)
		else
			@element.find(".user_answered").show()
			@element.find(".activity_container").fadeIn(500)
		$(".interaction").tooltip()
		@element.find(".quiz_container").fadeIn(500)

	submit_question_feedback: (element) =>
		conversation = element.closest('.conversation')
		if element.hasClass 'btn-success'
			return if element.hasClass 'disabled'
			element.addClass 'active'
			conversation.find('.btn').addClass('disabled')
		else
			return if element.hasClass 'disabled'
			return if element.hasClass 'active'
			element.addClass 'active'
			conversation.find('.btn-success').addClass('disabled')		
		params =
			type_id: element.attr 'type_id'
			question_id: conversation.attr 'question_id'
		@create_moderation('question', params)

	create_moderation: (moderation_type, params) =>
		$.post '/moderations', params
		
	submit_email: (element) =>
		element = element.parents('.request_email')
		params = 
			email: element.find("input").val()
		$.ajax '/users/add_email',
			type: 'POST'
			data: params
			success: (e) => 
				if e == true
					element.find('.content').fadeOut(500, => 
						element.find(".input-append").hide()
						element.find(".cta_message").css('position', 'relative').css('top', '4px').text("Thanks, you'll receive one this week!")
						element.find('.content').fadeIn()
					)
				else
					$(".request_email input").css('border-color', 'red')

$ -> 
	if $("#post_feed").length > 0
		open_publication = /feeds\/[0-9]+\/[0-9]+/.test(window.location.href)
		if open_publication
			publication_id = $('#post_id').val()
			target = $(".post[post_id=#{publication_id}]")
			if target.length > 1
				$(target[0]).parents('.conversation').remove()
				target = $(".post[post_id=#{publication_id}]")

		window.feed = new Feed
		if open_publication and target.length > 0
			target.parents('.conversation').removeClass('hidden')
			$.grep(window.feed.posts, (p) => p.id == publication_id)[0].expand(0)
			target.find("h3[answer_id=#{$('#answer_id').val()}]").click()
			$('html,body').animate({scrollTop: target.offset().top - 10}, 0);