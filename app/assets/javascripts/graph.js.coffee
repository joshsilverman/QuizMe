# window.onload = (e) ->
#   width = 960
#   height = 500
#   colors = d3.scale.category10()
#   svg = d3.select("body").append("svg").attr("width", width).attr("height", height)

#   nodes = [
#     id: 0
#     reflexive: false
#   ,
#     id: 1
#     reflexive: true
#   ,
#     id: 2
#     reflexive: false
#   ]
#   lastNodeId = 2
#   links = [
#     source: nodes[0]
#     target: nodes[1]
#     left: false
#     right: true
#   ,
#     source: nodes[1]
#     target: nodes[2]
#     left: false
#     right: true
#   ]
#   selected_node = null
#   selected_link = null
#   mousedown_link = null
#   mousedown_node = null
#   mouseup_node = null
#   lastKeyDown = -1

#   force = d3.layout.force().nodes(nodes).links(links).size([width, height]).linkDistance(150).charge(-500).on("tick", tick)
#   svg.append("svg:defs").append("svg:marker").attr("id", "end-arrow").attr("viewBox", "0 -5 10 10").attr("refX", 6).attr("markerWidth", 3).attr("markerHeight", 3).attr("orient", "auto").append("svg:path").attr("d", "M0,-5L10,0L0,5").attr "fill", "#000"
#   svg.append("svg:defs").append("svg:marker").attr("id", "start-arrow").attr("viewBox", "0 -5 10 10").attr("refX", 4).attr("markerWidth", 3).attr("markerHeight", 3).attr("orient", "auto").append("svg:path").attr("d", "M10,-5L0,0L10,5").attr "fill", "#000"
#   drag_line = svg.append("svg:path").attr("class", "link dragline hidden").attr("d", "M0,0L0,0")
#   path = svg.append("svg:g").selectAll("path")
#   circle = svg.append("svg:g").selectAll("g")
#   # set up SVG for D3
  
#   # set up initial nodes and links
#   #  - nodes are known by 'id', not by index in array.
#   #  - reflexive edges are indicated on the node (as a bold black circle).
#   #  - links are always source < target; edge directions are set by 'left' and 'right'.
  
#   # init D3 force layout
  
#   # define arrow markers for graph links
  
#   # line displayed when dragging new nodes
  
#   # handles to link and node element groups
  
#   # mouse event vars
#   resetMouseVars = ->
#     mousedown_node = null
#     mouseup_node = null
#     mousedown_link = null
  
#   # update force layout (called automatically each iteration)
#   tick = ->
    
#     # draw directed edges with proper padding from node centers
#     path.attr "d", (d) ->
#       deltaX = d.target.x - d.source.x
#       deltaY = d.target.y - d.source.y
#       dist = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
#       normX = deltaX / dist
#       normY = deltaY / dist
#       sourcePadding = (if d.left then 17 else 12)
#       targetPadding = (if d.right then 17 else 12)
#       sourceX = d.source.x + (sourcePadding * normX)
#       sourceY = d.source.y + (sourcePadding * normY)
#       targetX = d.target.x - (targetPadding * normX)
#       targetY = d.target.y - (targetPadding * normY)
#       "M" + sourceX + "," + sourceY + "L" + targetX + "," + targetY

#     circle.attr "transform", (d) ->
#       "translate(" + d.x + "," + d.y + ")"

  
#   # update graph (called when needed)
#   restart = ->
    
#     # path (link) group
#     path = path.data(links)
    
#     # update existing links
#     path.classed("selected", (d) ->
#       d is selected_link
#     ).style("marker-start", (d) ->
#       (if d.left then "url(#start-arrow)" else "")
#     ).style "marker-end", (d) ->
#       (if d.right then "url(#end-arrow)" else "")

    
#     # add new links
#     path.enter().append("svg:path").attr("class", "link").classed("selected", (d) ->
#       d is selected_link
#     ).style("marker-start", (d) ->
#       (if d.left then "url(#start-arrow)" else "")
#     ).style("marker-end", (d) ->
#       (if d.right then "url(#end-arrow)" else "")
#     ).on "mousedown", (d) ->
#       return  if d3.event.ctrlKey
      
#       # select link
#       mousedown_link = d
#       if mousedown_link is selected_link
#         selected_link = null
#       else
#         selected_link = mousedown_link
#       selected_node = null
#       restart()

    
#     # remove old links
#     path.exit().remove()
    
#     # circle (node) group
#     # NB: the function arg is crucial here! nodes are known by id, not by index!
#     circle = circle.data(nodes, (d) ->
#       d.id
#     )
    
#     # update existing nodes (reflexive & selected visual states)
#     circle.selectAll("circle").style("fill", (d) ->
#       (if (d is selected_node) then d3.rgb(colors(d.id)).brighter().toString() else colors(d.id))
#     ).classed "reflexive", (d) ->
#       d.reflexive

#     console.log circle
#     # add new nodes
#     g = circle.enter().append("svg:g")
    
#     # enlarge target node
    
#     # unenlarge target node
    
#     # select node
    
#     # reposition drag line
#     g.append("svg:circle").attr("class", "node").attr("r", 12).style("fill", (d) ->
#       (if (d is selected_node) then d3.rgb(colors(d.id)).brighter().toString() else colors(d.id))
#     ).style("stroke", (d) ->
#       d3.rgb(colors(d.id)).darker().toString()
#     ).classed("reflexive", (d) ->
#       d.reflexive
#     ).on("mouseover", (d) ->
#       return  if not mousedown_node or d is mousedown_node
#       d3.select(this).attr "transform", "scale(1.1)"
#     ).on("mouseout", (d) ->
#       return  if not mousedown_node or d is mousedown_node
#       d3.select(this).attr "transform", ""
#     ).on("mousedown", (d) ->
#       return  if d3.event.ctrlKey
#       mousedown_node = d
#       if mousedown_node is selected_node
#         selected_node = null
#       else
#         selected_node = mousedown_node
#       selected_link = null
#       drag_line.style("marker-end", "url(#end-arrow)").classed("hidden", false).attr "d", "M" + mousedown_node.x + "," + mousedown_node.y + "L" + mousedown_node.x + "," + mousedown_node.y
#       restart()
#     ).on "mouseup", (d) ->
#       return  unless mousedown_node
      
#       # needed by FF
#       drag_line.classed("hidden", true).style "marker-end", ""
      
#       # check for drag-to-self
#       mouseup_node = d
#       if mouseup_node is mousedown_node
#         resetMouseVars()
#         return
      
#       # unenlarge target node
#       d3.select(this).attr "transform", ""
      
#       # add link to graph (update if exists)
#       # NB: links are strictly source < target; arrows separately specified by booleans
#       source = undefined
#       target = undefined
#       direction = undefined
#       if mousedown_node.id < mouseup_node.id
#         source = mousedown_node
#         target = mouseup_node
#         direction = "right"
#       else
#         source = mouseup_node
#         target = mousedown_node
#         direction = "left"
#       link = undefined
#       link = links.filter((l) ->
#         l.source is source and l.target is target
#       )[0]
#       if link
#         link[direction] = true
#       else
#         link =
#           source: source
#           target: target
#           left: false
#           right: false

#         link[direction] = true
#         links.push link
      
#       # select new link
#       selected_link = link
#       selected_node = null
#       restart()

    
#     # show node IDs
#     g.append("svg:text").attr("x", 0).attr("y", 4).attr("class", "id").text (d) ->
#       d.id

    
#     # remove old nodes
#     circle.exit().remove()
    
#     # set the graph in motion
#     force.start()
#   mousedown = ->
    
#     # prevent I-bar on drag
#     #d3.event.preventDefault();
    
#     # because :active only works in WebKit?
#     svg.classed "active", true
#     return  if d3.event.ctrlKey or mousedown_node or mousedown_link
    
#     # insert new node at point
#     point = d3.mouse(this)
#     node =
#       id: ++lastNodeId
#       reflexive: false

#     node.x = point[0]
#     node.y = point[1]
#     nodes.push node
#     restart()
#   mousemove = ->
#     return  unless mousedown_node
    
#     # update drag line
#     drag_line.attr "d", "M" + mousedown_node.x + "," + mousedown_node.y + "L" + d3.mouse(this)[0] + "," + d3.mouse(this)[1]
#     restart()
#   mouseup = ->
    
#     # hide drag line
#     drag_line.classed("hidden", true).style "marker-end", ""  if mousedown_node
    
#     # because :active only works in WebKit?
#     svg.classed "active", false
    
#     # clear mouse event vars
#     resetMouseVars()
#   spliceLinksForNode = (node) ->
#     toSplice = links.filter((l) ->
#       l.source is node or l.target is node
#     )
#     toSplice.map (l) ->
#       links.splice links.indexOf(l), 1

  
#   # only respond once per keydown
#   keydown = ->
#     d3.event.preventDefault()
#     return  if lastKeyDown isnt -1
#     lastKeyDown = d3.event.keyCode
    
#     # ctrl
#     if d3.event.keyCode is 17
#       circle.call force.drag
#       svg.classed "ctrl", true
#     return  if not selected_node and not selected_link
#     switch d3.event.keyCode
#       # backspace
#       when 8, 46 # delete
#         if selected_node
#           nodes.splice nodes.indexOf(selected_node), 1
#           spliceLinksForNode selected_node
#         else links.splice links.indexOf(selected_link), 1  if selected_link
#         selected_link = null
#         selected_node = null
#         restart()
#       when 66 # B
#         if selected_link
          
#           # set link direction to both left and right
#           selected_link.left = true
#           selected_link.right = true
#         restart()
#       when 76 # L
#         if selected_link
          
#           # set link direction to left only
#           selected_link.left = true
#           selected_link.right = false
#         restart()
#       when 82 # R
#         if selected_node
          
#           # toggle node reflexivity
#           selected_node.reflexive = not selected_node.reflexive
#         else if selected_link
          
#           # set link direction to right only
#           selected_link.left = false
#           selected_link.right = true
#         restart()
#   keyup = ->
#     lastKeyDown = -1
    
#     # ctrl
#     if d3.event.keyCode is 17
#       circle.on("mousedown.drag", null).on "touchstart.drag", null
#       svg.classed "ctrl", false

#   console.log $("#askers")
#   askers = []
#   # $.each JSON.parse($("#askers").val()), (index, value) ->
#     # askers.push()
  
#   # app starts here
#   svg.on("mousedown", mousedown).on("mousemove", mousemove).on "mouseup", mouseup
#   d3.select(window).on("keydown", keydown).on "keyup", keyup
#   restart()