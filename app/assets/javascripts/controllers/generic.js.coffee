$ ->
  $('.dropdown a').dropdown()
  $('.best_in_place').best_in_place()
  $('.dropdown-toggle').dropdown()
  $('.has-tooltip').tooltip()

  window.snapper = new Snap
    element: $('.main-view')[0],
    disable: 'right'
  $('.menu-toggle').on('click', -> snapper.open('left'))