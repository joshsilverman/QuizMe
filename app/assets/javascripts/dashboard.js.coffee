class Dashboard
  display_data: null
  graph_data: null
  askers: null
  active: []
  dau_mau: null
  paulgraham: null
  handle_activity: null
  constructor: -> 
    @active.push("0") 
    $('#tabs a').click (e) => 
      e.preventDefault()
      @update_tabs(e)
    
    @core_data_by_handle = {}
    $('.handles a').click @core_by_handle

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
    if target == "#handles"
      if @handle_activity
        null
      else
        $(".loading").show()
        $.ajax "/get_handle_metrics"
          type: "GET"
          success: (e) => 
            $(".tab-content #handles").html(e)
            @handle_activity = $.parseJSON($("#handle_activity_data").val())    
            @cohort = $.parseJSON($("#cohort_activity").val())
            @draw_handle_activity()
            @draw_cohort_analysis()
          complete: -> $(".loading").hide()
    else if target == "#core"
      if !window.dashboard or !window.dashboard.core_data_by_handle['-1']
        @core()
    else if target == "#"
      return

    $('a[href=' + target + ']').tab('show')
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
      window.dashboard.core_data_by_handle['-1'] = data

      dashboard.draw_paulgraham('', data['paulgraham'])
      dashboard.draw_dau_mau('', data['dau_mau'])
      dashboard.draw_econ_engine('', data['econ_engine'])
      
      #dashboard.draw_daus('', data['daus'])
      dashboard.draw_revenue('', data['revenue'])

      $('.paulgraham_users .new .number').html data['core_display_data'][0]['paulgraham']['today']
      $('.paulgraham_users .total .number').html data['core_display_data'][0]['paulgraham']['total']

      $('.econ_engine .new .number').html data['core_display_data'][0]['econ_engine']['today']
      $('.econ_engine .month .number').html data['core_display_data'][0]['econ_engine']['month']

      $('.dau_mau .new .number').html data['core_display_data'][0]['dau_mau']['today']
      $('.dau_mau .total .number').html data['core_display_data'][0]['dau_mau']['total']

      #$('.daus .new .number').html data['core_display_data'][0]['daus']['today']
      #$('.daus .total .number').html data['core_display_data'][0]['daus']['total']

      $('.revenue .new .number').html data['core_display_data'][0]['revenue']['today']
      $('.revenue .total .number').html data['core_display_data'][0]['revenue']['month']
      
      $(".loading").hide()

  core_by_handle: -> 
    asker_id = $(this).attr('data-target').match(/#handle-([0-9]+)/)[1]
    asker_name = $(this).attr('handle-name')

    #tabs
    $('.nav-tabs > li').removeClass 'active'
    $('.nav-tabs > li.dropdown').addClass 'active'

    #tab content
    $('.tab-content .tab-pane').removeClass 'active'
    $('.tab-content #core_by_handle').addClass 'active'

    render = (data) ->
      dashboard.draw_paulgraham('#core_by_handle', data['paulgraham'])
      dashboard.draw_dau_mau('#core_by_handle', data['dau_mau'])
      dashboard.draw_daus('#core_by_handle', data['daus'])
      dashboard.draw_econ_engine('#core_by_handle', data['econ_engine'])

      $('#core_by_handle .paulgraham_users .new .number').html data['core_display_data'][0]['paulgraham']['today']
      $('#core_by_handle .paulgraham_users .total .number').html data['core_display_data'][0]['paulgraham']['total']

      $('#core_by_handle .econ_engine .new .number').html data['core_display_data'][0]['econ_engine']['today']
      $('#core_by_handle .econ_engine .month .number').html data['core_display_data'][0]['econ_engine']['month']

      # $('#core_by_handle .daus .new .number').html data['core_display_data'][0]['daus']['today']
      # $('#core_by_handle .daus .total .number').html data['core_display_data'][0]['daus']['total']

      $('#core_by_handle .dau_mau .new .number').html data['core_display_data'][0]['dau_mau']['today']
      $('#core_by_handle .dau_mau .total .number').html data['core_display_data'][0]['dau_mau']['total']

      $('#core_by_handle .daus .new .number').html data['core_display_data'][0]['daus']['today']
      $('#core_by_handle .daus .total .number').html data['core_display_data'][0]['daus']['total']

    if !window.dashboard or !window.dashboard.core_data_by_handle[asker_id]
      $('#core_by_handle .handle_name .text').text asker_name
      $(".loading").show()
      $.get ("/dashboard/core_by_handle/" + asker_id), (data) ->
        data = $.parseJSON data if ($.type(data) == 'string')
        window.dashboard.core_data_by_handle[asker_id] = data

        render(data)
        $(".loading").hide()

    window.location.hash = "#core"

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
    $.each data, (k,v) -> 
      date_array = k.split("-")
      data_array.push(["#{date_array[1]}/#{date_array[2]}", v])
    graph_data = google.visualization.arrayToDataTable(data_array)

    if container == undefined
      chart_elmnt = $(".dau_mau_graph")[0]
    else
      chart_elmnt = $(container + " .dau_mau_graph")[0]

    chart = new google.visualization.LineChart(chart_elmnt)
    chart.draw graph_data, dau_mau_options    

  #draw_daus: (container, data) =>
  #  data_array = [["Date", "DAU"]]
  #  $.each data, (k,v) -> 
  #    date_array = k.split("-")
  #    data_array.push(["#{date_array[1]}/#{date_array[2]}", v])
  #  graph_data = google.visualization.arrayToDataTable(data_array)
  #  
  #  if container == undefined
  #    chart_elmnt = $(".daus_graph")[0]
  #  else
  #    chart_elmnt = $(container + " .daus_graph")[0]
  #
  #  chart = new google.visualization.LineChart(chart_elmnt)
  #  chart.draw graph_data, dau_mau_options  

  draw_revenue: (container, data) =>
    graph_data = google.visualization.arrayToDataTable(data)
    
    if container == undefined
      chart_elmnt = $(".revenue_graph")[0]
    else
      chart_elmnt = $(container + " .revenue_graph")[0]
  
    chart = new google.visualization.LineChart(chart_elmnt)
    chart.draw graph_data, dau_mau_options  

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

  draw_cohort_analysis: =>
    graph_data = google.visualization.arrayToDataTable(@cohort)
    chart = new google.visualization.AreaChart(document.getElementById("cohort_graph"))
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
    {areaOpacity: 0, lineWidth: 0, color:'#6C69D1', pointSize:3},
    {areaOpacity: 0, pointSize: 0, color:'#6C69D1', curveType: "function"}]
  isStacked: true
  colors: ['orange', 'green', 'orange', "#6C69D1"]

dau_mau_options = 
  width: 425
  height: 275
  legend: "none"
  pointSize: 6
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
  colors: ["#6C69D1"]

econ_engine_options =
  width: 425
  height: 275
  pointSize: 6
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
  colors: ["#6C69D1"]

handle_activity_options = 
  width: 1170
  height: 500
  legend: "none"
  pointSize: 6
  lineWidth: 3
  isStacked: true
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

cohort_options = 
  width: 1170
  height: 500
  legend: "none"
  pointSize: 3
  lineWidth: 1
  isStacked: true
  # colors: ["#BAC4FF", "#ABB7FF", "#99A8FF", "#8295FF", "#6D82FC", "#546EFF", "#3B58FF", "#2647FF", "#1438FF", "#052BFF"]
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

options = 
  width: 425
  height: 275
  legend: "none"
  pointSize: 6
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
