class FeedsHome
	constructor: ->
		check_twttr = =>
			if twttr and twttr.widgets
				@load_follow_buttons()
			else
				setTimeout (-> check_twttr()), 100

				@load_follow_buttons_timeouts = []
				$(document).scroll =>
					puts feeds_home.load_follow_buttons_timeouts
					$.each feeds_home.load_follow_buttons_timeouts, (i, t) -> clearTimeout(t)
					feeds_home.load_follow_buttons_timeouts = []

					feeds_home.load_follow_buttons_timeouts.push setTimeout ->
							feeds_home.load_follow_buttons()
						, 500

		check_twttr()
		$("#query").on "keyup", (e) => @query(e)

	load_tour: ->
		@tour = new Tour()
		@tour.addStep
			element: "#query"
			title: "Title of my popover"
			content: "Content of my popover"
		@tour.start()


	load_follow_buttons: ->
		$('a.twitter-follow-button').filter(->
				return false unless feeds_home.is_scrolled_into_view(this)
				return false if $(this).find("iframe").length > 0
				return true
			).each (i) ->
				feeds_home.load_follow_buttons_timeouts.push(setTimeout =>
						return false unless feeds_home.is_scrolled_into_view(this)
						return false if $(this).find("iframe").length > 0
						twttr.widgets.createFollowButton $(this).data('screen-name'), this, ((el) ->
							console.log "Follow button created."
						),
							size: "large",
							'count': "none",
							text: "follow",
							"showScreenName": 'false'
					, 120*(i-1) + Math.floor(((i-1)/4))*900)

	is_scrolled_into_view: (elem) ->
		docViewTop = $(window).scrollTop()
		docViewBottom = docViewTop + $(window).height()
		elemTop = $(elem).offset().top
		elemBottom = elemTop + $(elem).height()
		(elemBottom <= docViewBottom) and (elemTop >= docViewTop)

	query: (e) ->
		clearTimeout feeds_home.query_timeout
		feeds_home.query_timeout = setTimeout =>
				feeds_home.query_xhr.abort() if feeds_home.query_xhr
				q = $("#query")[0].value
				feeds_home.query_xhr = $.post "/feeds/search", {query: q}, (r) ->
					$('.asker').hide()
					$.each r, (i, asker) ->
						$(".asker[data-asker_id=#{asker.id}]").show()
					feeds_home.load_follow_buttons()
					$("#askers h3").html "Search results for \"#{q}\""
			, 750

$ -> 
	window.feeds_home = new FeedsHome if $("#feeds_home").length > 0
	window.feeds_home.load_tour()