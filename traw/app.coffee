# =============== Includes

path = require 'path'
fs = require 'fs'
util = require 'util'
program = require 'commander'
ShutdownHandler = require "./shutdown_handler"
ManagedJSON = require "./managed_json"
InteractiveServer = require "./interactive_server"
log = require "winston"

program.version "1.0.0"
program.option "-v, --verbose", "Log all information"

program.parse process.argv

consoleLogLevel = if program.verbose then "verbose" else "warn"
fileLogLevel = if program.verbose then "verbose" else "info"
log.remove log.transports.Console
log.add log.transports.File, filename: "traw.log", level: fileLogLevel
log.add log.transports.Console, colorize: yes, level: consoleLogLevel

# =============== Defines

CONFIGFILE = 'config.json'


# =============== Preparation

new ShutdownHandler().on 'exit', ->
  process.exit()


# =============== Configuration

lines = []
nextLines = 0

checkClearCanvas = ->
  totalVotes = 0
  votesNeeded = Math.ceil(server.clientCount * config.data.votesNeeded)
  for cid, client of server.clients
    totalVotes++ if client.clearCanvas
  if totalVotes >= votesNeeded
    lines = []
    nextLines = 0
    server.broadcast "reset", lines
  else
    server.broadcast "clear canvas votes", totalVotes

socketIoOptions =
  "log level": 1
  "transports": ["xhr-polling"]
  "polling duration": 10

server = new InteractiveServer "client", socketIoOptions, (socket, client) ->
  server.broadcast "user count", server.clientCount
  socket.emit "revision", config.data.revision
  socket.emit "reset", lines
  checkClearCanvas()
  socket.on "disconnect", ->
    server.broadcast "user count", server.clientCount
    checkClearCanvas()
    socket.broadcast.emit "remove client", socket.id
  socket.on "new line", (src, dst) ->
    if src? and dst?
      if config.data.cacheLines
        if (lines.length / 4) < config.data.cacheLinesLimit
          lines.push src.x
          lines.push src.y
          lines.push dst.x
          lines.push dst.y
        else
          lines[nextLines] = src.x
          lines[nextLines + 1] = src.y
          lines[nextLines + 2] = dst.x
          lines[nextLines + 3] = dst.y
          nextLines += 4
          if nextLines >= lines.length
            nextLines = 0
          
      socket.broadcast.emit "new line", client.id, src, dst
  socket.on "mouse move", (x, y) ->
    if x? and y?
      socket.broadcast.emit "mouse move", client.id, x, y
  socket.on "clear canvas", (clearCanvas) ->
    client.clearCanvas = clearCanvas
    checkClearCanvas()
  socket.on "smiley", (x, y) ->
    if x? and y?
      client.lastSmiley ?= 0
      if new Date().getTime() > client.lastSmiley + config.data.smileyDelay
        socket.broadcast.emit "smiley", x, y
        client.lastSmiley = new Date().getTime()

stillAliveInterval = null
listening = no

config = new ManagedJSON CONFIGFILE, (err) ->
  if err?
    console.log "Error in configuration: #{err}" if err?
  else
    console.log "Configuration file loaded."
    if not listening
      server.listen process.env.PORT || config.data.port
      listening = true
    else
      server.broadcast 'revision', config.data.revision
    clearInterval stillAliveInterval if stillAliveInterval?
    stillAliveInterval = setInterval ->
      server.broadcast 'still alive'
    , config.data.lifesign
    checkClearCanvas()
