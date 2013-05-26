class Experiment
  constructor: ->
    $('.experiment-header').click -> experiment.load_details($(this))

  load_details: (header) ->
    $.post "/experiments/show", name: header.data('name'), (res) ->
      puts header.find('.experiment-details td')
      header.next('.experiment-details').find('td').html res
      $([header.next('.experiment-details'), this]).toggleClass('active')

  confirmReset: (e) ->
    agree = confirm("This will delete all data for this experiment?")
    if agree
      return true
    else
      return false

  confirmDelete: ->
    agree = confirm("Are you sure you want to delete this experiment and all its data?")
    if agree
      return true
    else
      return false

  confirmWinner: ->
    agree = confirm("This will now be returned for all users. Are you sure?")
    if agree
      return true
    else
      return false

$ ->
  window.experiment = new Experiment if $(".experiments").length > 0