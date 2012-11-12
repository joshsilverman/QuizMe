class User
  constructor: ->
    $('.modal-backdrop, .button.close').click -> 
      $('.modal.hide.fade.in').removeClass('in')
      $('.modal-backdrop').fadeOut()


$ ->
  window.user = new User if $('.users').length > 0