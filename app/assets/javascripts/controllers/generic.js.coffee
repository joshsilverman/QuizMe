$ ->
  $('.dropdown a').dropdown()
  $('.best_in_place').best_in_place()
  $('.dropdown-toggle').dropdown()
  $('.has-tooltip').tooltip()

  window.snapper = new Snap
    element: $('.main-view')[0],
    disable: 'right',
    touchToDrag: false,
  $('.menu-toggle').on('click', -> snapper.open('left'))
  
  snapper.on('animated', ->
    return if ($('.main-view').css('transform') != 'none')
    setTimeout((-> $('.drawer').css('left':-500)), 100)
  )

  setInterval ->
      return if (   $('.main-view').css('transform') != 'none' \
                 && $('.main-view').css('transform') != 'matrix(1, 0, 0, 1, 0, 0)')
      drawer = $('.drawer')
      drawer.replaceWith(drawer)
      $('.drawer').css("z-index", "1");
    , 3000

  snapper.on('animating', -> $('.drawer').css('left':0))
  snapper.on('open', -> $('.drawer').css('left':0))
  snapper.on('drag', -> $('.drawer').css('left':0))