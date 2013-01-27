class Dashboard
  display_data: null
  graph_data: null
  askers: null
  active: []
  dau_mau: null
  paulgraham: null
  handle_activity: null
  constructor: -> 
    # @active.push("0") 
    $('#tabs a').click (e) =>
      e.preventDefault()
      @update_tabs(e)

    #load correct tab
    if window.location.href.match(/dashboard[#?]|dashboard$/)
      hash_exp = /#[^?]*$|#.*(?=\?)/
      if window.location.hash.match(hash_exp)
        hash = window.location.hash.match(hash_exp)[0]
      else
        hash = '#core'
      @update_tabs null, hash

  update_tabs: (e, target) =>
    target ||= $(e.target).tab().attr 'href'
    target = "#users-answer_source" if target == '#users'
    target = "#askers-handle_activity" if target == '#askers'
    target = "#authors-ugc" if target == '#authors'
    target = "#core" if target == '#' or target == ''
    party_graph = target.split("-")
    party = party_graph[0].replace /#/, ''
    graph = party_graph[1]

    if target == "#core"
      @core()
    else
      $("a[href=#{ target }] .loading").show()
      url = "/graph/#{ party }/#{ graph }"
      $.ajax url,
        type: "GET"
        success: (e) => 
          $(".tab-content ##{party}").html(e)
          this[graph] = $.parseJSON($("##{graph}_data").val())
          this["draw_#{graph}"]()
          $(".graphs > div").hide()
          $("##{ party }, .graphs .#{graph}").show()

          $(".dashboard .nav a").parent().removeClass "active"
          $(".dashboard .nav a[href=#{ target }]").parent().addClass "active"

          $('.dashboard .nav a').click (e) =>
            e.preventDefault()
            @update_tabs(e)
        complete: -> $(".dashboard .nav a .loading").hide()

    $('a[href=#' + party + ']').tab('show')
    window.location.hash = target

  core: -> 
    #tabs
    $('.nav-tabs > li').removeClass 'active'
    $('.core-metrics').addClass 'active'

    #tab content
    $('.tab-content .tab-pane').removeClass 'active'
    $('.tab-content #core').addClass 'active'

    $(".loading").show()
    $.get ("/dashboard/core_by_handle/-1"), (data) =>
      data = $.parseJSON(data) if ($.type(data) == 'string')

      dashboard.draw_paulgraham('', data['paulgraham'])
      dashboard.draw_dau_mau('', data['dau_mau'])
      dashboard.draw_econ_engine('', data['econ_engine'])
      dashboard.draw_revenue('', data['revenue'])

      $('.paulgraham_users .new .number').html data['core_display_data'][0]['paulgraham']['today']
      $('.paulgraham_users .total .number').html data['core_display_data'][0]['paulgraham']['total']

      $('.econ_engine .new .number').html data['core_display_data'][0]['econ_engine']['today']
      $('.econ_engine .month .number').html data['core_display_data'][0]['econ_engine']['month']

      $('.dau_mau .new .number').html data['core_display_data'][0]['dau_mau']['today']
      $('.dau_mau .total .number').html data['core_display_data'][0]['dau_mau']['total']

      $('.revenue .new .number').html data['core_display_data'][0]['revenue']['today']
      $('.revenue .total .number').html data['core_display_data'][0]['revenue']['month']
      
      $(".loading").hide()

  update_dashboard: =>
    @draw_graphs()
    @update_metrics()

  draw_paulgraham: (container, data) =>
    data_array = [['Date', 'Min', 'Max', "Over", 'Total', '7 Day Avg']]
    $.each data, (k,v) -> 
      v['avg'] = .2 if v['avg'] > .2
      data_array.push [k, .05, .05, .05, v['raw'], v['avg']]
    graph_data = google.visualization.arrayToDataTable(data_array)

    #scope chart container if container provided - this is if there are multiple types of the same graph
    if container == undefined
      chart_elmnt = $(".paulgraham_graph")[0]
    else
      chart_elmnt = $(container + " .paulgraham_graph")[0]

    chart = new google.visualization.ComboChart(chart_elmnt)
    chart.draw graph_data, pg_options

  draw_dau_mau: (container, data) =>
    data_array = [["Date", "Ratio"]]
    $.each data, (k,v) -> data_array.push([k, v])
    graph_data = google.visualization.arrayToDataTable(data_array)

    if container == undefined
      chart_elmnt = $(".dau_mau_graph")[0]
    else
      chart_elmnt = $(container + " .dau_mau_graph")[0]

    chart = new google.visualization.LineChart(chart_elmnt)
    chart.draw graph_data, dau_mau_options    

  draw_daus: (container, data) =>
    data_array = [["Date", "DAU"]]
    $.each data, (k,v) -> 
      date_array = k.split("-")
      data_array.push(["#{date_array[1]}/#{date_array[2]}", v])
    graph_data = google.visualization.arrayToDataTable(data_array)
    
    if container == undefined
      chart_elmnt = $(".daus_graph")[0]
    else
      chart_elmnt = $(container + " .daus_graph")[0]
  
    chart = new google.visualization.LineChart(chart_elmnt)
    chart.draw graph_data, dau_mau_options  

  draw_revenue: (container, data) =>
    graph_data = google.visualization.arrayToDataTable(data)
    
    if container == undefined
      chart_elmnt = $(".revenue_graph")[0]
    else
      chart_elmnt = $(container + " .revenue_graph")[0]
  
    chart = new google.visualization.AreaChart(chart_elmnt)
    chart.draw graph_data, revenue_options  

  draw_econ_engine: (container, data) =>
    graph_data = google.visualization.arrayToDataTable(data)
    
    if container == undefined
      chart_elmnt = $(".econ_engine_graph")[0]
    else
      chart_elmnt = $(container + " .econ_engine_graph")[0]

    chart = new google.visualization.LineChart(chart_elmnt)
    chart.draw graph_data, econ_engine_options

  draw_handle_activity: =>
    graph_data = google.visualization.arrayToDataTable(@handle_activity)
    chart = new google.visualization.ColumnChart(document.getElementById("handle_activity_graph"))
    chart.draw graph_data, handle_activity_options  

  draw_cohort: =>
    graph_data = google.visualization.arrayToDataTable(@cohort)
    chart = new google.visualization.AreaChart(document.getElementById("cohort_graph"))
    chart.draw graph_data, cohort_options      

  draw_ugc: => 
    graph_data = google.visualization.arrayToDataTable(@ugc)
    chart = new google.visualization.LineChart(document.getElementById("ugc_graph"))
    chart.draw graph_data, questions_options 

  draw_questions_answered: =>
    graph_data = google.visualization.arrayToDataTable(@questions_answered)
    chart = new google.visualization.LineChart(document.getElementById("questions_graph"))
    chart.draw graph_data, questions_options          

  draw_learner_levels: =>
    graph_data = google.visualization.arrayToDataTable(@learner_levels)
    chart = new google.visualization.PieChart(document.getElementById("learner_levels_graph"))
    chart.draw graph_data, learner_levels_options 

  draw_answer_source: =>
    graph_data = google.visualization.arrayToDataTable(@answer_source)
    chart = new google.visualization.AreaChart(document.getElementById("answer_source_graph"))
    chart.draw graph_data, cohort_options 

  draw_lifecycle: =>
    graph_data = google.visualization.arrayToDataTable(@lifecycle)
    chart = new google.visualization.AreaChart(document.getElementById("lifecycle_graph"))
    chart.draw graph_data, cohort_options 

  draw_age_v_reengagement_v_response_rate: =>
    graph_data = google.visualization.arrayToDataTable(@age_v_reengagement_v_response_rate)
    chart = new google.visualization.ColumnChart(document.getElementById("age_v_reengagement_v_response_rate_graph"))
    chart.draw graph_data, age_v_reengagement_v_response_rate_graph_options 

$ -> window.dashboard = new Dashboard if $(".core, .dashboard").length > 0

pg_options = 
  width: 425
  height: 275
  legend: "none"
  chartArea:  
    width: 420
    left: 30
    height: 225
  hAxis:
    textStyle: 
      fontSize: 9
  vAxis:
    viewWindowMode: 'explicit'
    viewWindow:
      max: 0.1501
      min: 0
  series: [
    {type:'area', lineWidth:0},
    {type:'area', lineWidth:0},
    {type:'area', lineWidth:0},
    {areaOpacity: 0, lineWidth: 0, color:'#1D3880', pointSize:2},
    {areaOpacity: 0, pointSize: 0, color:'#1D3880', curveType: "function"}]
  isStacked: true
  colors: ['orange', 'green', 'orange', "#1D3880"]

learner_levels_options = 
  width: 850
  height: 450
  pointSize: 3
  lineWidth: 3
  chartArea:  
    height: 520
    width: 620
    left: 195
    top:35
  hAxis:
    textStyle: 
      fontSize: 9
  vAxis:
    viewWindowMode: 'explicit'
    viewWindow:
      min: 0
  colors: [
    "#C9D4FF",
    "#9EB0F7", 
    "#6A82DE",
    "#3F58BA",
    "#213996",
    "#0E2066",
    "#000C3B"
  ]

dau_mau_options = 
  width: 425
  height: 275
  legend: "none"
  pointSize: 5
  lineWidth: 3
  chartArea:  
    width: 420
    left: 30
    height: 225
  vAxis:
    viewWindowMode: 'explicit'
    viewWindow:
      min: 0
  hAxis:
    textStyle: 
      fontSize: 9
    slantedText: true
  colors: ["#1D3880"]

econ_engine_options =
  width: 425
  height: 275
  pointSize: 5
  lineWidth: 3
  chartArea:  
    width: 420
    left: 30
    height: 225
  hAxis:
    textStyle: 
      fontSize: 9
  vAxis:
    minorGridlines:
      count: 3
      color: "#eee"
    viewWindowMode: 'explicit'
    viewWindow:
      min: 0
  colors: ["#1D3880"]

revenue_options = 
  width: 425
  height: 275
  legend: "none"
  pointSize: 0
  lineWidth: 3
  isStacked: true
  colors: [
    "#B1C2F0", 
    "#5E79C4",
    "#1D3880"
  ]
  chartArea:  
    width: 420
    left: 30
    height: 225
  hAxis:
    textStyle: 
      fontSize: 9
  vAxis:
    viewWindowMode: 'explicit'
    viewWindow:
      min: 0

handle_activity_options = 
  width: 850
  height: 520
  legend: "none"
  pointSize: 3
  lineWidth: 2
  isStacked: true
  chartArea:  
    width: 820
    left: 42
    height: 380
    top: 15
  hAxis:
    textStyle: 
      fontSize: 11
    slantedTextAngle: 90
  vAxis:
    viewWindowMode: 'explicit'
    viewWindow:
      min: 0

questions_options = 
  width: 1170
  height: 450
  legend: "none"
  pointSize: 5
  lineWidth: 2
  colors: [
    "#1D3880",
    "#E01B6A"
  ]
  chartArea:  
    left: 42
    height:400
  hAxis:
    textStyle: 
      fontSize: 9
    slantedText: true
  vAxis:
    viewWindowMode: 'explicit'
    viewWindow:
      min: 0

cohort_options = 
  width: 850
  height: 450
  legend: "none"
  pointSize: 0
  lineWidth: 0.25
  isStacked: true
  colors: [
    "#B1C2F0", 
    "#5E79C4",
    "#1D3880"
  ]
  chartArea:  
    width: 1170
    left: 42
    height: 400
  hAxis:
    textStyle: 
      fontSize: 9
    slantedText: true
  vAxis:
    viewWindowMode: 'explicit'
    viewWindow:
      min: 0

age_v_reengagement_v_response_rate_graph_options = 
  width: 850
  height: 500
  legend: "none"
  pointSize: 0
  lineWidth: 0.25
  colors: [
    "#B1C2F0", 
    "#5E79C4",
    "#1D3880"
  ]
  chartArea:  
    width: 780
    left: 42
    height: 450
  hAxis:
    textStyle: 
      fontSize: 9
    slantedText: true
    direction:1
  vAxis:
    0: 
      logScale: false,
    1: 
      logScale: false, 
      maxValue: 1
  series:
     0:
      targetAxisIndex:0,
     1:
      targetAxisIndex:1,
     2:
      targetAxisIndex:1

options = 
  width: 425
  height: 275
  legend: "none"
  pointSize: 3
  lineWidth: 3
  chartArea:  
    width: 420
    left: 30
    height: 225
  hAxis:
    textStyle: 
      fontSize: 9
  vAxis:
    viewWindowMode: 'explicit'
    viewWindow:
      min: 0

line_colors = 
  0: "#6C69D1"
  2: "#69D175"
  19: "#D1B269"
  31: "#D169C1"
  66: "#D1696A"

Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1
Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output
