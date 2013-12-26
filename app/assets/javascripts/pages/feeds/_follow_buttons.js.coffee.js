class FollowButtons
  constructor: ->
    @load_follow_buttons_timeouts = []

    check_twttr = =>
      if (typeof twttr == 'undefined') or !twttr.widgets
        setTimeout (=> check_twttr()), 100
      else
        @load_follow_buttons()
        $(document).scroll =>
          $.each follow_buttons.load_follow_buttons_timeouts, (i, t) -> clearTimeout(t)
          follow_buttons.load_follow_buttons_timeouts = []

          follow_buttons.load_follow_buttons_timeouts.push setTimeout ->
              follow_buttons.load_follow_buttons()
            , 500
        twttr.events.bind 'follow', (e) => @afterfollow(e)

    check_twttr()

  load_follow_buttons: ->
    $('a.twitter-follow-button').filter(->
        return false unless follow_buttons.is_scrolled_into_view(this)
        return false if $(this).find("iframe").length > 0
        return true
      ).each (i) ->
        follow_buttons.load_follow_buttons_timeouts.push(setTimeout =>
            return false unless follow_buttons.is_scrolled_into_view(this)
            return false if $(this).find("iframe").length > 0
            twttr.widgets.createFollowButton $(this).data('screen-name'), this, ((el) ->
              # console.log "Follow button created."
            ),
              size: "large",
              'count': "none",
              text: "follow",
              "showScreenName": 'false'
          , 220*(i-1) + Math.floor(((i-1)/4))*900)

  is_scrolled_into_view: (elem) ->
    docViewTop = $(window).scrollTop()
    docViewBottom = docViewTop + $(window).height()
    elemTop = $(elem).offset().top
    elemBottom = elemTop + $(elem).height()
    (elemBottom <= docViewBottom) and (elemTop >= docViewTop) 

  afterfollow: (e) ->
    $.ajax '/experiments/trigger',
      type: 'post'
      data: {experiment: "New Landing Page"}

$ ->
  if ($('#post_feed').length > 0)
    window.follow_buttons = new FollowButtons