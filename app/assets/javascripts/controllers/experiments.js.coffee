class Experiment
  constructor: ->
    $('.experiment-header').click -> experiment.load_details($(this))
    $('#concluded_tab').click -> experiment.load_concluded_tab()
    $('#search_terms_tab').click -> experiment.load_search_terms_tab()
    $('#concluded_search_terms_tab').click -> experiment.load_concluded_search_terms_tab()

  load_details: (header) ->
    $.post "/experiments/show", name: header.data('name'), (res) ->
      header.next('.experiment-details').find('td').html res
      $([header.next('.experiment-details'), this]).toggleClass('active')

  load_concluded_tab: ->
    $.get "/experiments/index_concluded", (res) -> 
      $("#concluded").html res
      $('#concluded_tab').off 'click'
      $('.experiment-header').off 'click'
      $('.experiment-header').click -> experiment.load_details($(this))
  
  load_search_terms_tab: ->
    $.get "/experiments/index_search_terms", (res) -> 
      $("#search_terms").html res
      $('#search_terms_tab').off 'click'
      $('.experiment-header').off 'click'
      $('.experiment-header').click -> experiment.load_details($(this))      

  load_concluded_search_terms_tab: ->
    $.get "/experiments/index_concluded_search_terms", (res) -> 
      $("#concluded_search_terms").html res
      $('#concluded_search_terms_tab').off 'click'
      $('.experiment-header').off 'click'
      $('.experiment-header').click -> experiment.load_details($(this))            

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