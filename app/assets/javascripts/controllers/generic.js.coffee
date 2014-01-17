$ ->
  $('.dropdown a').dropdown()
  $('.best_in_place').best_in_place()
  $('.dropdown-toggle').dropdown()
  $('.has-tooltip').tooltip()

  window.snapper = new Snap
    element: $('.main-view')[0],
    disable: 'right',
    touchToDrag: false
  $('.menu-toggle').on('click', -> snapper.open('left'))
  
  snapper.on('animated', ->
    return if ($('.main-view').css('transform') != 'none')
    $('.drawer').removeClass('show')
  )

  setInterval ->
      if ($('.main-view').css('transform') != 'none' && $('.main-view').css('transform') != 'matrix(1, 0, 0, 1, 0, 0)')
          return

      $('.drawer').removeClass('show')
    , 10

  snapper.on('animating', -> $('.drawer').addClass('show'))
  snapper.on('open', -> $('.drawer').addClass('show'))
  snapper.on('drag', -> $('.drawer').addClass('show'))