# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

class Badge
  constructor: ->
    $(".badge-image").click -> 
      console.log "badge image click"
      return if $(this).hasClass 'faded'
      console.log $(this).closest('.badge-image-wrapper')
      $(this).closest('.badge-image-wrapper').next(".modal").modal()

    $('.issue.btn').click -> window.badge.issue(this)

  issue: (btn) ->
    console.log $(btn)
    console.log $(btn).closest('.modal')
    console.log $(btn).closest('.modal').attr "user_id"

    $.post "/badges/issue",
        user_id: $(btn).closest('.modal').attr "user_id"
        badge_id: $(btn).closest('.modal').attr "badge_id"
        tweet: $(btn).closest('.modal').find('.question_text').text()
      , ->
        modal = $(btn).closest('.modal')
        console.log modal
        modal.modal('hide')

$ ->
  window.badge = new Badge if $(".badges").length > 0