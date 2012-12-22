class Report
  @waus = {}

  constructor: -> 
    @waus = $.parseJSON($("#waus").html())
    console.log @waus
    @render()

    $('.wau-periods a').click @show_wau_period
    $('.nudge').click @nudge

  render: ->
    @draw_waus()

  draw_waus: ->
    graph_data = google.visualization.arrayToDataTable(@waus)
    chart = new google.visualization.AreaChart(document.getElementById("waus_graph"))
    chart.draw graph_data, options

  show_wau_period: ->

    $.each ['activity', 'people'], (i, selector) =>

      if this.href.match(/#[^#]*$/)[0] == "##{selector}"
        #tabs
        $('.nav-tabs > li').removeClass 'active'
        $(".nav-tabs > li.dropdown.#{selector}").addClass 'active'

        # tab content wau periods
        $("##{selector} .wau-period").removeClass 'active'
        $($(this).attr('data-target')).addClass 'active'

        #tab content
        $('.tab-pane').removeClass 'active'
        $("##{selector}").addClass 'active'

  nudge: ->
    $(this).html "..."
    $.ajax
      type: 'POST',
      url: '/clients/nudge',
      data:
        user_id: $(this).attr('user_id'),
        asker_id: $(this).attr('asker_id'),
      success: => 
        console.log "success"
        window.ttthis = $(this)
        $(this).closest('.asker-row').addClass('info')
        $(this).closest('td').html ""
      failure: => 
        console.log "failure"
        window.ttthis = $(this)
        $(this).closest('td').html "fail :/"

$ -> 
  window.report = new Report if $(".report").length > 0

options = 
  width: 864
  height: 280
  legend: 
    position: 'in'
  pointSize: 6
  lineWidth: 3
  isStacked: true
  chartArea:  
    width: 845
    left: 5
    height: 210
  hAxis:
    textStyle: 
      fontSize: 9
  vAxis:
    textPosition: 'in'