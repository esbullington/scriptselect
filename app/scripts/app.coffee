Backbone.pubSub = _.extend({}, Backbone.Events)

sizing = ->
  windowwidth = $(window).width()
  containerwidth = $(".container").width()
  diff = windowwidth - containerwidth + 40
  $("#leftmargin").text "window=" + windowwidth + ",container=" + containerwidth
  if diff > 0
    $("#leftmargin").css "margin-left", (diff / 2) + "px"
  else
    $("#leftmargin").css "margin-left", "20px"
$(document).ready sizing
$(window).resize sizing


$.getJSON "scripts/cdn.json", (data)->
  SCRIPT_COLLECTION = data

  class Script extends Backbone.Model

    initialize: ->
      # _.bindAll(this, "toggle")

    toggle: ->
      currentStatus = this.get('done')
      this.set('done', !currentStatus)
      this.collection.trigger("status-changed")


    defaults:
      "name": "defaultname"
      "source": "http://www.default.com"
      "cdn": "http://www.default.com"
      "bytes": 0
      "index": 0
      "done": false


  class ScriptCollection extends Backbone.Collection
    model: Script

    calculateTotal: ->
      total = 0
      this.each((model)->
        if model.get('done')
          total = total + model.get('bytes')
        total
      )
      total

    selectedScripts: ->
      selected = []
      this.each((model)->
        if model.get('done')
         selected.push(model)
      )
      selected


  class ItemView extends Backbone.View

    initialize: ->
      _.bindAll(this, "render", "toggleStatus")

    events:
      "click .check": "toggleStatus"

    tagName: "label"

    className: "checkbox"

    template: $('#script-template').html()

    toggleStatus:() ->
      this.$(".check").toggleClass("checked")
      this.model.toggle()
      payload = this.$(".check")[0].value
      if this.$(".check")[0].checked
        Backbone.pubSub.trigger('color-bar', payload)
        this.dropDown()
      else
        Backbone.pubSub.trigger('color-bar-off', payload)
        this.dropUp()

    dropDown: ->
      console.log "working"
      console.log this
      namearray = this.model.get("name").split(".")
      name = namearray[0] + namearray[1]
      this.$el.append("<div class='" +name + " cdnname' ><strong>CDN</strong>: " + this.model.get("cdnname") + "</div>")
      source = this.model.get("source")
      this.$el.append("<div class='" + name + " sourcename'><strong>Project site:</strong> <a href='" + source + "' >" + source + "</a></div>")

    dropUp: =>
      window.myel = this.$el
      namearray = this.model.get("name").split(".")
      name = namearray[0] + namearray[1]
      $('.' + name).remove()

    render: (index)->
      templ = _.template(this.template)
      this.model.set("index", index)
      this.$el.html(templ(this.model.toJSON()))
      this


  class ScriptCollectionView extends Backbone.View

    initialize: ->
      _.bindAll(this, "render")

    el: "#content"

    events: {
      'click .list.btn': 'clearList'
    }

    clearList: ->
      $("#content input").each((index,item)->
        payload = $(item).val() if $(item).is(":checked") is true
        Backbone.pubSub.trigger('color-bar-off', payload)
        $(item).attr("checked", false)

      )
      $(".cdnname").remove()
      $(".sourcename").remove()
      this.collection.each(
        (item,index)->
          item.set("done", false)
          console.log item.get("done")
      )
      Backbone.pubSub.trigger('clear-list')

    ### Would this render method perform better? ###
    # render: ->
    #   $(this.el).empty()
    #   els = []
    #   this.collection.each((model, index)->
    #     view = new ItemView( model:model )
    #     els.push(view.render(index).el)
    #   )
    #   $(this.el).append(els)
    #   this

    render: =>
      this.$el.append("<button class='list btn'>Clear list</button>")
      this.collection.each(
        (item, index)-> this.renderItem(item, index),
        this
      )

    renderItem: (item, index)=>
      itemView = new ItemView model:item
      this.$el.append(itemView.render(index).el)

  class ListView extends Backbone.View

    initialize: =>
      # _.bindAll(this, "render", "toggleStatus")
      @itemList = []
      Backbone.pubSub.on('color-bar', this.onMakePie, this)
      Backbone.pubSub.on('color-bar-off', this.onMakePieOff, this)


    onMakePie: (name)=>
      this.collection.each(
        (item, index)=>
          if item.get("name") is name
            @itemList.push(item)
      )
      @render(@itemList)

    onMakePieOff: (name)=>
      item = index = null
      _.each(@itemList, (item,index,list)->
        if item.get("name") is name
          list.splice(index,1)
      )
      @render(@itemList)

    el: "#script-list"

    # className: "checkbox"

    template: $('#html-template').html()

    render: (scripts)=>
      this.$el.empty()
      if scripts
        for model in scripts
          this.renderItem(model)
      this

    renderItem: (model)=>
      name = model.get('name')
      templ = _.template(this.template)
      this.$el.append(templ(name:name))



  class HTMLView extends Backbone.View

    initialize: ->
      _.bindAll(this, "render")
      this.collection.bind("status-changed", this.render)
      this.collection.bind("status-changed", this.hola)
      Backbone.pubSub.on('clear-list', this.render)

    el: "#html-content"

    render: =>
      this.$el.empty()
      fullscript = ""
      count = 0
      this.collection.each((model,index)=>
        if model.get("done")
          fullscript += this.renderItem(model)
          count++
      )
      str = "<textarea onclick='this.focus();this.select();' style='overflow:hidden;' cols=300 rows='#{count*2}' id='script-textarea' readonly='readonly'>#{fullscript}</textarea>"
      this.$el.append(str)


    renderItem: (model)->
      cdn = model.get('cdn')
      return '<script src="' + cdn + '"></script>\n'


  class StatsView extends Backbone.View

    initialize: ->
      _.bindAll(this, "render")
      this.collection.bind("status-changed", this.render)

    el: "#stats"

    template: $('#stats-template').html()

    render: ->
      total = this.collection.calculateTotal()
      estimatedBroadBand = total/((5000/8)*1000)
      estimatedMobile = total/((1000/8)*1000)
      totalCount = filesize(total)
      templ = _.template(this.template)
      this.$el.html(templ(
        totalCount: totalCount
        estimatedMobile: estimatedMobile
        estimatedBroadBand: estimatedBroadBand
      ))
      this


  class PieChartView extends Backbone.View

    initialize:(data)->
      # _.bindAll(this, "render")
      # this.collection.bind("status-changed", this.render)
      Backbone.pubSub.on('color-bar', this.onMakePie, this)
      Backbone.pubSub.on('color-bar-off', this.onMakePieOff, this)

    el: "#piechart"

    pieData: []

    initialPieData: [{bytes: 0, name: ""}]

    render: ()->
      @renderPie(@initialPieData)

    onMakePie: (name)->
      this.collection.each(
        (item, index)=>
          if item.get("name") is name
            @initialPieData.push(item.toJSON())
      )
      d3.select("#piechart-group").remove()
      @renderPie(@initialPieData)

    onMakePieOff: (name)=>
      _.each(@initialPieData, (item,index,list)->
        if item.name is name
          list.splice(index,1)
      )
      d3.select("#piechart-group").remove()
      @renderPie(@initialPieData)
      # if @pieData.length is 0
      #   @renderPie(@initialPieData)
      # else
      #   @renderPie(@pieData)

    renderPie: (data)->
      w = 400 #width
      h = 290 #height
      r = 100 #radius
      labelr = r + 15
      activated = false
      color = d3.scale.category20c() #builtin range of colors
      vis = d3.select("#piechart")
        .append("svg:svg")
        .attr("id", "piechart-group")
        .data([data])
        .attr("width", w)
        .attr("height", h)
        .append("svg:g")
        .attr("transform", "translate(" + (r+100) + "," + (r+50) + ")")
        .on("mouseover",()-> if data.length <= 1 and activated is false
          d3.select(this).append("svg:text").attr("id", "text-notice").attr("x", -70).text("Please select a script").style("opacity", 0).transition().duration(400).style("opacity", 1).each("end", ()=> d3.select(this).append("svg:text").attr("y", 20).attr("id", "arrow-notice").text("->").style("opacity", 0).transition().duration(400).style("opacity", 1))
          activated = true
      )
      arc = d3.svg.arc().outerRadius(r)
      #this will create arc data for us given a list of values
      pie = d3.layout.pie().value((d) -> #we must tell it out to access the value of each element in our data array
        if data.length is 1
          1
        else
          d.bytes
      )
      tooltip = "undefined"
      #this selects all <g> elements with class slice (there aren't any yet)
      arcs = vis.selectAll("g.slice")
        .data(pie)
        .enter()
        .append("svg:g")
        .attr("class", "slice") #allow us to style things in the slices (like text)
        .on("mouseover",(d,i) ->
          if data.length > 1
            d3.select(this).attr("fill", "#e6550d")
        )
        .on("mouseout", (d,i)->
          d3.select(this).attr("fill", "black")
        )

      #set the color for each slice to be chosen from the color function defined above
      arcs.append("svg:path")
        .attr("fill", (d, i) ->
          if d.data.bytes is 0
            "grey"
          else
            color(i)
        )
        .attr("stroke", "black")
          # if data.length is 2
          #   "none"
          # else
          #   "black")
        .attr("stroke-width", .5)
        .attr("d", arc)

      tblock = arcs.append("svg:text")
        .attr("transform", (d) ->
          d.innerRadius = 0
          d.outerRadius = r
          c = arc.centroid(d)
          x = c[0]
          y = c[1]
          h = Math.sqrt(x * x + y * y)
          "translate(" + (x / h * labelr) + "," + (y / h * labelr) + ")"
        )
        .attr("class", "label")
        .attr("dy", ".35em")
        .attr("text-anchor", (d) ->
          if (d.endAngle + d.startAngle) / 2 > Math.PI
            "end"
          else
            "start"
        )
        .text (d, i) =>
          if (d.endAngle + d.startAngle) / 4 < Math.PI
            namearray = d.data.name.split(".")
            if namearray.length < 2
              namearray
            else
              if namearray[1] is "js"
                namearray[0]
              else
                namearray[1]
      tblock2 = arcs.append("svg:text")
        .attr("transform", (d) ->
          d.innerRadius = 0
          d.outerRadius = r
          c = arc.centroid(d)
          x = c[0]
          y = c[1]
          h = Math.sqrt(x * x + y * y)
          "translate(" + (x / h * labelr) + "," + ((y / h * labelr)+12) + ")"
        )
        .attr("class", "label")
        .attr("dy", ".35em")
        .attr("text-anchor", (d) ->
          if (d.endAngle + d.startAngle) / 2 > Math.PI
            "end"
          else
            "start"
        )
        .text (d, i) =>
          if (d.endAngle + d.startAngle) / 3.6 < Math.PI
            filesize(d.data.bytes)
      


  scriptCollection = new ScriptCollection(SCRIPT_COLLECTION)

  scriptView = new ScriptCollectionView(
    collection: scriptCollection
  )

  statsView = new StatsView(
    collection: scriptCollection
  )


  listView = new ListView(
    collection: scriptCollection
  )

  htmlView = new HTMLView(
    collection: scriptCollection
  )

  pieChartView = new PieChartView(
    collection: scriptCollection
  )

  statsView.render()
  scriptView.render()
  listView.render()
  htmlView.render()
  pieChartView.render()




