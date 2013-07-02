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
    $('#tabs li a').click (e) =>
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

    #domains selectable
    $('.domains a').click -> 
      hash_exp = /#[^?]*$|#.*(?=\?)/
      target = window.location.hash.match(hash_exp)[0]
      dashboard.update_tabs null, target, $(this).attr 'domain'

  update_tabs: (e, target, domain) =>
    target ||= $(e.target).tab().attr 'href'
    target = "#users-answer_source" if target == '#users'
    target = "#askers-handle_activity" if target == '#askers'
    target = "#authors-ugc" if target == '#authors'
    target = "#moderators-user_moderated_posts" if target == '#moderators'
    target = "#core" if target == '#' or target == ''
    party_graph = target.split("-")
    party = party_graph[0].replace /#/, ''
    graph = party_graph[1]

    #domain
    if domain == undefined
      match = window.location.href.match(/\?domain=([0-9]+)/)
      domain = match[1] if match and match.length >= 1
      domain ||= 30

    if target == "#core"
      @core(domain)
    else
      $("a[href=#{ target }] .loading").show()

      match = window.location.href.match(/\?[^#]+|\?[\w\W]+/)
      qs = match[0] if match
      qs ||= '?'
      qs += "&domain=#{domain}"

      url = "/graph/#{ party }/#{ graph }#{qs}"
      $.ajax url,
        type: "GET"
        success: (e) => 
          $('.reloadable .graph').remove()
          $(".tab-content ##{party}").html(e)

          this[graph] = $.parseJSON($(".#{graph} #data").val())
          draw_func = this["draw_#{graph}"]

          if draw_func
            draw_func()
          else
            this.draw_generic this[graph], 'ColumnChart'

          $(".dashboard .nav a").parent().removeClass "active"
          $(".dashboard .nav a[href=#{ target }]").parent().addClass "active"

          $('.dashboard .nav a').click (e) =>
            e.preventDefault()
            @update_tabs(e)
        complete: -> 
          $(".dashboard .nav a .loading").hide()
          dashboard.after_update(domain)

    $('a[href=#' + party + ']').tab('show')

    #edit hash - does not work for yc_admin?
    match = window.location.href.match(/\?[^#]+|\?[\w\W]+/)
    qs = match[0] if match
    qs ||= ''
    window.location.hash = qs + target

  core: (domain = 30) ->
    #tabs
    $('.nav-tabs > li').removeClass 'active'
    $('.core-metrics').addClass 'active'

    #tab content
    $('.tab-content .tab-pane').removeClass 'active'
    $('.tab-content #core').addClass 'active'

    match = window.location.href.match(/\?[^#]+|\?[\w\W]+/)
    qs = match[0] if match
    qs ||= '?'
    qs += "&domain=#{domain}"

    party = 'core'
    $.each ['paulgraham', 'dau_mau', 'econ_engine', 'quality_response'], (i, graph) =>
      url = "/graph/#{ party }/#{ graph }#{qs}"
      $.ajax url,
        success: (data) =>
          draw_func = this["draw_#{graph}"]
          draw_func(data[0])

          $(".#{graph} .new .number").html data[1]['today']
          $(".#{graph} .total .number").html data[1]['total']

  update_dashboard: =>
    @draw_graphs()
    @update_metrics()

  after_update: (domain) ->
    hash_exp = /#[^?]*$|#.*(?=\?)/
    target = window.location.hash.match(hash_exp)[0]

    $(".domains a").removeClass "active"
    $(".domains a[domain=#{domain}]").addClass "active"
    window.location.hash = "#{target}?domain=#{domain}"

  draw_paulgraham: (data) =>
    data_array = [['Date', 'Min', 'Max', "Over", 'Total', '7 Day Avg']]
    $.each data, (i,r) ->
      date = r[0]
      ratio = r[1]
      avg = r[2]
      avg = .2 if avg > .2
      ratio = .2 if ratio > .2
      data_array.push [date, .05, .05, .05, ratio, avg]

    graph_data = google.visualization.arrayToDataTable(data_array)
    chart = new google.visualization.LineChart($(".paulgraham_graph")[0])
    chart.draw graph_data, pg_options

  draw_dau_mau: (data) =>
    data_array = [["Date", "Ratio"]]
    $.each data, (k,v) -> data_array.push([k, v])
    graph_data = google.visualization.arrayToDataTable(data_array)
    chart = new google.visualization.LineChart($(".dau_mau_graph")[0])
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

  draw_quality_response: (data) =>
    graph_data = google.visualization.arrayToDataTable(data)
    chart = new google.visualization.AreaChart($(".quality_response_graph")[0])
    chart.draw graph_data, revenue_options  

  draw_econ_engine: (data) =>
    graph_data = google.visualization.arrayToDataTable(data)
    chart = new google.visualization.LineChart($(".econ_engine_graph")[0])
    chart.draw graph_data, econ_engine_options

  draw_handle_activity: =>
    graph_data = google.visualization.arrayToDataTable(@handle_activity)
    chart = new google.visualization.ColumnChart(document.getElementById("graph"))
    chart.draw graph_data, handle_activity_options  

  draw_cohort: =>
    graph_data = google.visualization.arrayToDataTable(@cohort)
    chart = new google.visualization.AreaChart(document.getElementById("graph"))
    chart.draw graph_data, cohort_options      

  draw_ugc: => 
    graph_data = google.visualization.arrayToDataTable(@ugc)
    chart = new google.visualization.LineChart(document.getElementById("graph"))
    chart.draw graph_data, questions_options 

  draw_questions_answered: =>
    graph_data = google.visualization.arrayToDataTable(@questions_answered)
    chart = new google.visualization.LineChart(document.getElementById("graph"))
    chart.draw graph_data, questions_options          

  draw_learner_levels: =>
    graph_data = google.visualization.arrayToDataTable(@learner_levels)
    chart = new google.visualization.PieChart(document.getElementById("graph"))
    chart.draw graph_data, learner_levels_options 

  draw_answer_source: =>
    graph_data = google.visualization.arrayToDataTable(@answer_source)
    chart = new google.visualization.AreaChart(document.getElementById("graph"))
    chart.draw graph_data, cohort_options 

  draw_lifecycle: =>
    graph_data = google.visualization.arrayToDataTable(@lifecycle)
    chart = new google.visualization.AreaChart(document.getElementById("graph"))
    chart.draw graph_data, cohort_options 

  draw_age_v_reengagement_v_response_rate: =>
    graph_data = google.visualization.arrayToDataTable(@age_v_reengagement_v_response_rate)
    chart = new google.visualization.ColumnChart(document.getElementById("graph"))
    chart.draw graph_data, age_v_reengagement_v_response_rate_graph_options

  draw_days_since_active_when_reengaged_v_response_rate: =>
    graph_data = google.visualization.arrayToDataTable(@days_since_active_when_reengaged_v_response_rate)
    chart = new google.visualization.ColumnChart(document.getElementById("graph"))
    chart.draw graph_data, generic_ColumnChart_options 

  draw_days_since_active_v_number_of_reengagement_attempts: =>
    graph_data = new google.visualization.DataTable()
    graph_data.addColumn 'number', 'Days'
    graph_data.addColumn 'number', 'Reengagements'
    graph_data.addColumn type: 'number', role: 'tooltip'
    graph_data.addColumn 'number', 'Reengagements (inactive user)'
    graph_data.addColumn type: 'number', role: 'tooltip'
    graph_data.addRows @days_since_active_v_number_of_reengagement_attempts
    chart = new google.visualization.ScatterChart(document.getElementById("graph"))
    chart.draw graph_data, days_since_active_v_number_of_reengagement_attempts_graph_options 
  
  draw_age_v_days_since_active: =>
    graph_data = google.visualization.arrayToDataTable(@age_v_days_since_active)
    chart = new google.visualization.ScatterChart(document.getElementById("graph"))
    chart.draw graph_data, age_v_days_since_active_graph_options 

  draw_viral_actions_v_new_users: =>
    graph_data = google.visualization.arrayToDataTable(@viral_actions_v_new_users)
    chart = new google.visualization.LineChart(document.getElementById("graph"))
    chart.draw graph_data, age_v_days_since_active_graph_options

  draw_generic: (data, type) =>
    data = google.visualization.arrayToDataTable(data)
    chart = new google.visualization[type](document.getElementById("graph"))
    chart.draw data, window["generic_#{type}_options"]

  draw_user_moderated_posts: =>
    graph_data = google.visualization.arrayToDataTable(@user_moderated_posts)
    chart = new google.visualization.AreaChart(document.getElementById("graph"))
    chart.draw graph_data, cohort_options  

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
  pointSize: 3
  lineWidth: 2
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
  pointSize: 3
  lineWidth: 2
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
  lineWidth: 2
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
  width: 850
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
    width: 780
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
      logScale: false
    1: 
      logScale: false
      maxValue: 1
  series:
     0:
      targetAxisIndex:0
     1:
      targetAxisIndex:1
     2:
      targetAxisIndex:1

window.generic_ColumnChart_options =
  width: 860
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
    width: 770
    left: 55
    height: 450
  hAxis:
    textStyle: 
      fontSize: 9
    slantedText: true
    direction:1
  vAxis:
    0: 
      logScale: false
    1: 
      logScale: false
      maxValue: 1
  series:
     0:
      targetAxisIndex:0
     1:
      targetAxisIndex:1
     2:
      targetAxisIndex:1

days_since_active_v_number_of_reengagement_attempts_graph_options = 
  width: 860
  height: 500
  legend: "none"
  pointSize: 0.5
  colors: [
    "blue",
    "red"
  ]
  chartArea:  
    width: 770
    left: 55
    height: 450
  hAxis:
    textStyle: 
      fontSize: 9
    slantedText: true
    direction:1
    minorGridlines:
      count: 7
      color: "#eee"
  #  viewWindow:
  #    max: 120
  #vAxis:
  #  viewWindow:
  #    max: 4

age_v_days_since_active_graph_options = 
  width: 860
  height: 500
  legend: "none"
  pointSize: 0.1
  colors: [
    "#5E79C4",
    "#1D3880"
  ]
  chartArea:  
    width: 770
    left: 55
    height: 450
  hAxis:
    textStyle: 
      fontSize: 9
    slantedText: true
    direction:1

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
