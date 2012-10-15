class Report
  @waus = {}

  constructor: -> 
    @waus = $.parseJSON($("#waus").html())
    console.log @waus
    @render()

    $('.wau-periods a').click @show_wau_period

  render: ->
    @draw_waus()

  draw_waus: ->
    graph_data = google.visualization.arrayToDataTable(@waus)
    chart = new google.visualization.AreaChart(document.getElementById("waus_graph"))
    chart.draw graph_data, options

  show_wau_period: ->

    if this.href.match(/#[^#]*$/)[0] == "#activity"

      #wau periods
      $('.wau-period').removeClass 'active'
      $($(this).attr('data-target')).addClass 'active'

      #tabs
      $('.nav-tabs > li').removeClass 'active'
      $('.nav-tabs > li.dropdown').addClass 'active'

      #tab content
      $('.tab-pane').removeClass 'active'
      $("#activity").addClass 'active'


$ -> 
  window.report = new Report if $(".report").length > 0

options = 
  width: 864
  height: 280
  legend: "none"
  pointSize: 6
  lineWidth: 3
  chartArea:  
    width: 845
    left: 5
    height: 210
  hAxis:
    textStyle: 
      fontSize: 9
  vAxis:
    textPosition: 'in'