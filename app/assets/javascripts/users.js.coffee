class User
  constructor: ->
    $('.modal-backdrop, .button.close').click -> 
      $('.modal.hide.fade.in').removeClass('in')
      $('.modal-backdrop').fadeOut()

    $('abbr.timeago').timeago()



$ ->
  window.user = new User if $('.users, .supporters').length > 0