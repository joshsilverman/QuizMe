# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

class Badge
  constructor: ->
    $(".badge-image").click -> $(this).closest('.badge-image-wrapper').next(".modal").modal()

$ ->
  window.badge = new Badge if $(".badges").length > 0