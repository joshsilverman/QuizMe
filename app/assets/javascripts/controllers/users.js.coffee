class User
  constructor: ->
    $('.modal-backdrop, .button.close').click -> 
      $('.modal.hide.fade.in').removeClass('in')
      $('.modal-backdrop').fadeOut()
    $('abbr.timeago').timeago()

class Unsubscribe
	constructor: ->
		@user_id = $("#user_id").val()
		$("input").focus()
		$(".btn").on "click", (e) =>
			e.preventDefault()
			params =
				"user_id" : @user_id
				"email" : $("input").val()
			$.ajax '/unsubscribe',
				type: 'POST',
				data: params,
				success: (e) => 
					if e == true
						$(".status").removeClass("alert-success").addClass("alert-error").text("Sorry, email address does not match.").fadeIn()
					else
						$(".status").removeClass("alert-error").addClass("alert-success").text("Successfully unsubscribed.").fadeIn()

$ ->
  window.user = new User if $('.users, .supporters').length > 0
  window.unsubscribe = new Unsubscribe if $("#unsubscribe").length > 0