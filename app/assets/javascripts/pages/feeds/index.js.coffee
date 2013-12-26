class FeedsHome
	constructor: ->
		check_twttr = =>
			if (typeof twttr == 'undefined') or !twttr.widgets
				setTimeout (=> check_twttr()), 100
			else
				feeds_home.load_follow_buttons_timeouts = []
				@load_follow_buttons()
				$(document).scroll =>
					puts feeds_home.load_follow_buttons_timeouts
					$.each feeds_home.load_follow_buttons_timeouts, (i, t) -> clearTimeout(t)
					feeds_home.load_follow_buttons_timeouts = []

					feeds_home.load_follow_buttons_timeouts.push setTimeout ->
							feeds_home.load_follow_buttons()
						, 500

				twttr.events.bind 'follow', (e) => @afterfollow(e)

		check_twttr()
		$("#query").on "keyup", (e) => @query(e)
		$("#query").focus()

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
				return if q.length < 2
				$('.header .searching').show()
				feeds_home.query_xhr = $.post "/feeds/search", {query: q}, (r) ->
					$('.asker').hide()
					$.each r, (i, asker) ->
						$(".asker[data-asker_id=#{asker.id}]").show()
					feeds_home.load_follow_buttons()
					$("#askers h3.text").html "Search results for \"#{q}\""
					$('.header .searching').hide()
			, 500

	afterfollow: (e) ->
		$.gritter.add
			title: "@#{e.data.screen_name}",
			text: "Thanks for following! I'll DM you a question shortly."
			image: $("img[title=#{e.data.screen_name}]").attr 'src'
			time:9000

		$.ajax '/experiments/trigger',
			type: 'post'
			data: {experiment: "New Landing Page"}

$ -> 
	window.feeds_home = new FeedsHome if $("#feeds_home").length > 0