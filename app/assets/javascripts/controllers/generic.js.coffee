$ ->
  $('.dropdown a').dropdown()
  $('.best_in_place').best_in_place()
  $('.dropdown-toggle').dropdown()
  $('.has-tooltip').tooltip()

  window.snapper = new Snap
    element: $('.main-view')[0],
    disable: 'right'
  $('.menu-toggle').on('click', -> snapper.open('left'))
  
  snapper.on('animated', ->
    return if ($('.main-view').css('transform') != 'none')
    setTimeout((-> $('.drawer').css('width':0)), 100)
  )
  snapper.on('animating', -> $('.drawer').css('width':266))
  snapper.on('open', -> $('.drawer').css('width':266))
  snapper.on('drag', -> $('.drawer').css('width':266))