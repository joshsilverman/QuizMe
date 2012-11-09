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
      console.log(window.location.hash);
      hash_exp = /#[^?]*$|#.*(?=\?)/
      if window.location.hash.match(hash_exp)
        hash = window.location.hash.match(hash_exp)[0]
      else
        hash = false

      console.log(hash);
      return

      if hash != false
        $(hash).addClass "active"
        $(".nav-tabs a[href=" + hash + "]").parent('li').addClass "active"
      else
        tab_id = $('.tab-content .tab-pane')[0].id
        $("#" + tab_id).addClass "active"
        $(".nav-tabs a[href=#" + tab_id + "]").parent('li').addClass "active"
      @update_tabs null, hash

  update_tabs: (e, target) =>
    console.log e
    target ||= $(e.target).tab().attr 'href'
    if target == "#detailed"
      if $("#detailed").is(':empty')
        $.ajax "/get_detailed_metrics"
          type: "GET"
          success: (e) => 
            $(".tab-content #detailed").append(e)
            @graph_data = $.parseJSON($("#detailed_graph_data").val())
            @display_data = $.parseJSON($("#detailed_display_data").val())
            @draw_graphs()
            @update_metrics()             
            $(".select_option").on "change", (e) => 
              if $(e.target).attr("value") == "0" and $(e.target).is(":checked") 
                @active.splice(0, 0, "0")
              else
                if $(e.target).is(":checked") 
                  @active.push($(e.target).attr "value") 
                else 
                  @active.remove($(e.target).attr "value")
              @update_dashboard()
            @update_dashboard()               
    else if target == "#handles"
      if $("#handles").is(':empty')
        $.ajax "/get_handle_metrics"
          type: "GET"
          success: (e) => 
            $(".tab-content #handles").append(e)
            @handle_activity = $.parseJSON($("#handle_activity_data").val())    
            @draw_handle_activity()
    else if target == "#"
      return

    $(e.target).tab('show')
    window.location.hash = target

  core_by_handle: -> 
    asker_id = $(this).attr('data-target').match(/#handle-([0-9]+)/)[1]
    asker_name = $(this).attr('handle-name')

    #tabs
    $('.nav-tabs > li').removeClass 'active'
    $('.nav-tabs > li.dropdown').addClass 'active'

    #tab content
    $('.tab-content .tab-pane').removeClass 'active'
    $('.tab-content #core_by_handle').addClass 'active'

    #handles
    $.get ("/dashboard/core_by_handle/" + asker_id), (data) ->
      window.dashboard.core_data_by_handle[asker_id] = data

      dashboard.draw_paulgraham('#core_by_handle', data['paulgraham'])
      dashboard.draw_dau_mau('#core_by_handle', data['dau_mau'])
      dashboard.draw_daus('#core_by_handle', data['daus'])
      dashboard.draw_econ_engine('#core_by_handle', data['econ_engine'])

      $('#core_by_handle .paulgraham_users .new .number').html data['core_display_data'][0]['paulgraham']['today']
      $('#core_by_handle .paulgraham_users .total .number').html data['core_display_data'][0]['paulgraham']['total']

      $('#core_by_handle .econ_engine .new .number').html data['core_display_data'][0]['econ_engine']['today']
      $('#core_by_handle .econ_engine .total .number').html data['core_display_data'][0]['econ_engine']['answerers']

      $('#core_by_handle .daus .new .number').html data['core_display_data'][0]['daus']['today']
      $('#core_by_handle .daus .total .number').html data['core_display_data'][0]['daus']['total']

      $('#core_by_handle .dau_mau .new .number').html data['core_display_data'][0]['dau_mau']['today']
      $('#core_by_handle .dau_mau .total .number').html data['core_display_data'][0]['dau_mau']['total']

      console.log $('#core_by_handle .handle_name')
      console.log asker_name
      $('#core_by_handle .handle_name').text asker_name

  update_dashboard: =>
    @draw_graphs()
    @update_metrics()
  update_metrics: =>
    askers = []
    display_hash = 
      followers: today: 0, total: 0
      active_users: today: [], total: []
      questions_answered: today: 0, total: []
      click_throughs: today: 0, total: 0
      mentions: today: 0, total: 0
      retweets: today: 0, total: 0
    if "0" in @active then askers.push(0) else askers.push(asker_id) for asker_id in @active
    for asker_id in askers
      for key of display_hash
        if key == "active_users"
          display_hash[key]["today"] = display_hash[key]["today"].concat(@display_data[asker_id][key]["today"])
          display_hash[key]["total"] = display_hash[key]["total"].concat(@display_data[asker_id][key]["total"])
        else if key == "questions_answered"
          display_hash[key]["today"] += @display_data[asker_id][key]["today"]
          display_hash[key]["total"] = display_hash[key]["total"].concat(@display_data[asker_id][key]["total"])       
        else
          display_hash[key]["today"] += @display_data[asker_id][key]["today"]
          display_hash[key]["total"] += @display_data[asker_id][key]["total"]
    for key, value of display_hash
      if key == "active_users"
        $("##{key}_stats .new .number").text(value.today.unique().length)
        $("##{key}_stats .total .number").text(value.total.unique().length)
      else if key == "questions_answered"
        $("##{key}_stats .new .number").text(value.today)
        $("##{key}_stats .total .number").text(value.total.unique().length)
      else
        $("##{key}_stats .new .number").text(value.today)
        $("##{key}_stats .total .number").text(value.total)
  draw_graphs: =>
    colors = []
    colors.push(line_colors[asker_id]) for asker_id in @active
    options.colors = colors
    title_row = ["Date"]
    accounts = []
    accounts.push(asker_id) for asker_id, data of @askers
    for account_id in @active
      if account_id == "0" then title_row.push("Total") else title_row.push(@askers[account_id][0].twi_screen_name) 
    for attribute_name, attribute_data of @graph_data
      continue if attribute_name == "active_users" or attribute_name == "click_throughs"
      data_array = [title_row]
      for date, asker_data of attribute_data
        date_array = date.split("-")
        row = ["#{date_array[1]}/#{date_array[2]}"]
        row.push(0) for i in @active
        if "0" in @active
          if attribute_name == "active_user_ids" then total = [] else total = 0
          for asker_id, data of @askers
            if asker_data[asker_id] == undefined or asker_data[asker_id] == null
              row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = 0 if asker_id in @active
            else
              if attribute_name == "active_user_ids" 
                row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id].unique().length if asker_id in @active
                total = total.concat(asker_data[asker_id])
              else
                row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id] if asker_id in @active
                total += asker_data[asker_id]
          if attribute_name == "active_user_ids"
            row[title_row.indexOf("Total")] = total.unique().length
          else 
            row[title_row.indexOf("Total")] = total
        else
          for asker_id in @active
            if asker_data[asker_id] == undefined or asker_data[asker_id] == null
              row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = 0
            else
              if attribute_name == "active_user_ids" 
                row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id].unique().length
              else
                row[title_row.indexOf(@askers[asker_id][0].twi_screen_name)] = asker_data[asker_id]     
        data_array.push(row)
      graph_data = google.visualization.arrayToDataTable(data_array)
      chart = new google.visualization.LineChart(document.getElementById("#{attribute_name}_graph"))
      chart.draw graph_data, options

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

  draw_econ_engine: (container, data) =>
    graph_data = google.visualization.arrayToDataTable(data)
    
    if container == undefined
      chart_elmnt = $(".econ_engine_graph")[0]
    else
      chart_elmnt = $(container + " .econ_engine_graph")[0]

    chart = new google.visualization.AreaChart(chart_elmnt)
    chart.draw graph_data, econ_engine_options

  draw_handle_activity: =>
    graph_data = google.visualization.arrayToDataTable(@handle_activity)
    chart = new google.visualization.ColumnChart(document.getElementById("handle_activity_graph"))
    chart.draw graph_data, handle_activity_options  

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
  isStacked: true
  width: 425
  height: 275
  pointSize: 0
  lineWidth: 0
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

handle_activity_options = 
  width: 1100
  height: 550
  legend: "none"
  pointSize: 6
  lineWidth: 3
  isStacked: true
  title: "Total Social Interactions this Week"
  chartArea:  
    width: 1100
    left: 50
    height: 450
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
