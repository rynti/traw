window.console ?= log: ->


jQuery(document).ready ($) ->
  allLines = []
  previousPosition = null
  container = $('#container')
  canvas = null
  context = null
  $document = $(document)
  $window = $(window)
  first = yes
  currentRevision = -1

  showResetBoxTimeout = null
  showResetBox = ->
    if showResetBoxTimeout?
      clearTimeout showResetBoxTimeout
    $('.reset').fadeIn()
    showResetBoxTimeout = setTimeout ->
      $('.reset').fadeOut()
      showResetBoxTimeout = null
    , 2000

  noConnectionTimeout = null
  hasConnection = ->
    $('.no-connection').fadeOut()
    if noConnectionTimeout?
      clearTimeout noConnectionTimeout
    noConnectionTimeout = setTimeout ->
      noConnectionTimeout = null
      $('.no-connection').fadeIn()
    , 5000

  hasConnection()

  socket = io.connect "http://#{document.location.host}"
  socket.on "revision", (revision) ->
    if currentRevision < 0
      currentRevision = revision
    else if currentRevision < revision
      document.location.reload yes

  socket.on "remove client", (cid) ->
    $(".cursor-#{cid}").remove()

  socket.on "still alive", ->
    hasConnection()

  socket.on "reset", (lines) ->
    $('.cursors').empty()
    allLines = lines
    showResetBox() if not first
    first = no

    container.empty()
    canvas = $('<canvas>').prop width: $window.width(), height: $window.height()
    canvas.appendTo(container)
    context = canvas[0].getContext '2d'
    for i in [0..lines.length] by 4
      drawLine lines[i], lines[i + 1], lines[i + 2], lines[i + 3]

  socket.on "mouse move", (cid, x, y) ->
    if $(".cursor-#{cid}").length == 0
      $(".cursors").append $("<div>").addClass("cursor").addClass("cursor-#{cid}")
    $(".cursor-#{cid}").css left: "#{x}px", top: "#{y}px"

  socket.on "new line", (cid, src, dst) ->
    allLines.push src.x, src.y, dst.x, dst.y
    drawLine src.x, src.y, dst.x, dst.y
    if $(".cursor-#{cid}").length == 0
      $(".cursors").append $("<div>").addClass("cursor").addClass("cursor-#{cid}")
    $(".cursor-#{cid}").css left: "#{dst.x}px", top: "#{dst.y}px"

  lastUpdate = 0

  newLine = (src, dst) ->
    socket.emit 'new line', src, dst
    drawLine src.x, src.y, dst.x, dst.y

  drawLine = (srcX, srcY, dstX, dstY) ->
    context.moveTo srcX, srcY
    context.lineTo dstX, dstY
    context.stroke()

  onMouseDown = (e) ->
    e.preventDefault()
    previousPosition = x: e.pageX, y: e.pageY

  onMouseUp = (e) ->
    e.preventDefault()
    return if not previousPosition?
    currentPosition = x: e.pageX, y: e.pageY
    newLine previousPosition, currentPosition
    previousPosition = null

  onMouseMove = (e) ->
    e.preventDefault()
    return if new Date().getTime() <= lastUpdate + 25
    lastUpdate = new Date().getTime()
    if previousPosition?
      currentPosition = x: e.pageX, y: e.pageY
      newLine previousPosition, currentPosition
      previousPosition = currentPosition
    else
      socket.emit "mouse move", e.pageX, e.pageY


  resizeTimeout = null

  onResize = (e) ->
    if resizeTimeout?
      clearTimeout resizeTimeout
      resizeTimeout = null
    resizeTimeout = setTimeout ->
      resizeTimeout = null
      canvas.prop width: $window.width(), height: $window.height()
      context = canvas[0].getContext '2d'
      context.clearRect 0, 0, canvas.width(), canvas.height()
      for i in [0..allLines.length] by 4
        drawLine allLines[i], allLines[i + 1], allLines[i + 2], allLines[i + 3]
    , 200
  
  $window.resize onResize
  $document.mousedown onMouseDown
  $document.mouseup onMouseUp
  $document.mousemove onMouseMove

