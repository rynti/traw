window.console ?= log: ->

jQuery(document).ready ($) ->
  allLines = []
  touches = {}
  previousPosition = null
  container = $('#container')
  canvas = null
  context = null
  $document = $(document)
  $window = $(window)
  first = yes
  currentRevision = -1
  clearCanvas = no
  inputLocked = no
  scaleFactorX = 1
  scaleFactorY = 1
  scaleOffsetX = 0
  scaleOffsetY = 0
  LINE_WIDTH = 3
  UPDATE_LIMIT = 15

  $('.lock-input').click (e) ->
    e.preventDefault()
    if inputLocked
      inputLocked = no
      $('.lock-input').removeClass 'btn-primary'
      $('.lock-input i').removeClass 'icon-white'
    else
      inputLocked = yes
      $('.lock-input').addClass 'btn-primary'
      $('.lock-input i').addClass 'icon-white'

  $('.clear-canvas').click (e) ->
    e.preventDefault()
    toggleClearCanvasVote()

  refreshScaleFactors = ->
    if canvas.width() > canvas.height()
      scaleFactorX = canvas.width()
      scaleFactorY = canvas.width()
      scaleOffsetX = 0
      scaleOffsetY = (canvas.width() - canvas.height()) / 2
    else
      scaleFactorX = canvas.height()
      scaleFactorY = canvas.height()
      scaleOffsetX = (canvas.height() - canvas.width()) / 2
      scaleOffsetY = 0
  normX = (x) -> (x + scaleOffsetX) / scaleFactorX
  normY = (y) -> (y + scaleOffsetY) / scaleFactorY
  scaleX = (x) -> x * scaleFactorX - scaleOffsetX
  scaleY = (y) -> y * scaleFactorY - scaleOffsetY

  spawnSmiley = (x, y) ->
    x = scaleX x
    y = scaleY y
    smiley = $('<div>').addClass('smiley').appendTo('.smileys').css left: "#{x}px", top: "#{y}px"
    smiley.fadeIn 200, ->
      setTimeout ->
        smiley.fadeOut 750, ->
          smiley.remove()
      , 1050

  toggleClearCanvasVote = ->
    if clearCanvas
      clearCanvas = no
      $('.clear-canvas').removeClass 'btn-success'
      $('.clear-canvas i').removeClass 'icon-white'
    else
      clearCanvas = yes
      $('.clear-canvas').addClass 'btn-success'
      $('.clear-canvas i').addClass 'icon-white'
    socket.emit 'clear canvas', clearCanvas


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

  socket.on "user count", (count) ->
    $('.total-people span').text count

  socket.on "revision", (revision) ->
    if currentRevision < 0
      currentRevision = revision
    else if currentRevision < revision
      document.location.reload yes

  socket.on "clear canvas votes", (votes) ->
    $(".clear-canvas-votes").text "#{votes}"

  socket.on "remove client", (cid) ->
    $(".cursor-#{cid}").remove()

  socket.on "still alive", ->
    hasConnection()

  socket.on "reset", (lines) ->
    $('.cursors').empty()
    toggleClearCanvasVote() if clearCanvas
    allLines = lines
    showResetBox() if not first
    first = no

    container.empty()
    canvas = $('<canvas>').prop width: $window.width(), height: $window.height()
    canvas.mousedown onMouseDown
    canvas[0].ontouchstart = onTouchStart
    canvas.appendTo(container)
    context = canvas[0].getContext '2d'
    context.lineCap = 'round'
    context.lineWidth = LINE_WIDTH
    refreshScaleFactors()
    context.beginPath()
    for i in [0..lines.length] by 4
      drawLine lines[i], lines[i + 1], lines[i + 2], lines[i + 3]
    context.stroke()

  socket.on "mouse move", (cid, x, y) ->
    x = scaleX x
    y = scaleY y
    if $(".cursor-#{cid}").length == 0
      $(".cursors").append $("<div>").addClass("cursor").addClass("cursor-#{cid}")
    $(".cursor-#{cid}").css left: "#{x}px", top: "#{y}px"

  socket.on "new line", (cid, src, dst) ->
    allLines.push src.x, src.y, dst.x, dst.y
    context.beginPath()
    drawLine src.x, src.y, dst.x, dst.y
    context.stroke()
    if $(".cursor-#{cid}").length == 0
      $(".cursors").append $("<div>").addClass("cursor").addClass("cursor-#{cid}")
    $(".cursor-#{cid}").css left: "#{dst.x}px", top: "#{dst.y}px"

  socket.on "smiley", (x, y) ->
    spawnSmiley x, y

  lastUpdate = 0

  newLine = (src, dst) ->
    allLines.push src.x, src.y, dst.x, dst.y
    socket.emit 'new line', src, dst
    context.beginPath()
    drawLine src.x, src.y, dst.x, dst.y
    context.stroke()

  drawLine = (srcX, srcY, dstX, dstY) ->
    context.moveTo scaleX(srcX), scaleY(srcY)
    context.lineTo scaleX(dstX), scaleY(dstY)

  onMouseDown = (e) ->
    e.preventDefault()
    return if inputLocked
    if e.button is 0  # left click
      previousPosition = x: normX(e.pageX), y: normY(e.pageY)
    else if e.button is 2  # right click
      socket.emit 'smiley', normX(e.pageX), normY(e.pageY)
      spawnSmiley normX(e.pageX), normY(e.pageY)

  onMouseUp = (e) ->
    e.preventDefault()
    return if inputLocked
    if e.button is 0  # left click
      return if not previousPosition?
      currentPosition = x: normX(e.pageX), y: normY(e.pageY)
      newLine previousPosition, currentPosition
      previousPosition = null

  onMouseMove = (e) ->
    e.preventDefault()
    return if new Date().getTime() <= lastUpdate + UPDATE_LIMIT
    lastUpdate = new Date().getTime()
    if previousPosition? and not inputLocked
      currentPosition = x: normX(e.pageX), y: normY(e.pageY)
      newLine previousPosition, currentPosition
      previousPosition = currentPosition
    else
      socket.emit "mouse move", normX(e.pageX), normY(e.pageY)

  onTouchStart = (e) ->
    e.preventDefault()
    for i, v in e.touches
      touches[i] = x: normX(e.pageX), y: normY(e.pageY)
    #$('.total-people span').text e.touches[0].pageX + " : " + e.touches[0].pageY
    #onMouseDown pageX: e.touches[0].pageX, pageY: e.touches[0].pageY
    #alert e.touches[0].pageX
    #x = ""
    #for k, v of e
    #  x += k + "\n"
    #alert x
  onTouchMove = (e) ->
    e.preventDefault()
    for i, v in e.touches
      t = x: normX(e.pageX), y: normY(e.pageY)
      newLine touches[i], t
      # $('.total-people span').text t.x - touches[i].x
      touches[i] = t
    # $('.total-people span').text e.touches[0].pageX + " : " + e.touches[0].pageY
    # onMouseMove pageX: e.touches[0].pageX, pageY: e.touches[0].pageY
    # onMouseMove e.touches[0]
  onTouchEnd = (e) ->
    e.preventDefault()
    # $('.total-people span').text e.touches[0].pageX + " : " + e.touches[0].pageY
    # onMouseUp pageX: e.touches[0].pageX, pageY: e.touches[0].pageY
    # onMouseUp e.touches[0]

  resizeTimeout = null

  onResize = (e) ->
    if resizeTimeout?
      clearTimeout resizeTimeout
      resizeTimeout = null
    resizeTimeout = setTimeout ->
      resizeTimeout = null
      canvas.prop width: $window.width(), height: $window.height()
      context = canvas[0].getContext '2d'
      context.lineCap = 'round'
      context.lineWidth = LINE_WIDTH
      context.clearRect 0, 0, canvas.width(), canvas.height()
      refreshScaleFactors()
      context.beginPath()
      for i in [0..allLines.length] by 4
        drawLine allLines[i], allLines[i + 1], allLines[i + 2], allLines[i + 3]
      context.stroke()
    , 10
  
  $document.mouseup onMouseUp
  $document.mousemove onMouseMove
  document.ontouchmove = onTouchMove
  document.ontouchend = onTouchEnd
  $window.resize onResize
  document.oncontextmenu = (e) -> return false

