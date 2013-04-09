url = require 'url'
path = require 'path'
mime = require 'mime'
fs = require 'fs'
http = require 'http'
coffee = require 'coffee-script'
socketio = require 'socket.io'
events = require 'events'

INDEXFILE = 'index.html'


class InteractiveServer extends events.EventEmitter
  constructor: (@clientDirectory, arg1, arg2) ->
    socketIoOptions = "log level": 1
    if arg1?
      if typeof arg1 is "function"
        @on "connection", arg1
      else
        socketIoOptions = arg1
    if arg2?
      if typeof arg2 is "function"
        @on "connection", arg2
      else
        socketIoOptions = arg2
    
    @clients = {}
    @listener = http.createServer @handler
    @listener.on "listening", =>
      @io = socketio.listen @listener, socketIoOptions
      @io.sockets.on "connection", (socket) =>
        @clients[socket.id] = {}
        @clients[socket.id].id = socket.id
        @clients[socket.id].socket = socket
        @emit "connection", socket, @clients[socket.id]

  listen: (port, hostname) => @listener.listen port, hostname

  broadcast: (args...) => @io.sockets.emit args...

  handler: (req, res) =>
    uri = decodeURI url.parse(req.url).pathname
    if uri[uri.length - 1] is '/'
      uri += INDEXFILE
    filename = path.join @clientDirectory, uri
    handleFile = (exists) ->
      if not exists
        res.writeHead 404, 'Content-Type': 'text/html'
        res.end '<h1>404</h1><p>Not found</p>'
        return
      stats = fs.stat filename, (err, stats) ->
        if err or not stats.isFile()
          res.writeHead 403, 'Content-Type': 'text/html'
          res.end '<h1>403</h1><p>Forbidden</p>'
          return
        res.writeHead 200, {
          'Content-Type': mime.lookup(filename),
          'Content-Length': stats.size
        }
        fs.createReadStream(filename).pipe res

    extension = path.extname(filename)
    if extension is '.js'
      base = path.join path.dirname(filename), path.basename filename, extension
      scriptName = base + ".coffee"
      fs.exists scriptName, (exists) ->
        if not exists
          fs.exists filename, handleFile
        else
          stats = fs.stat scriptName, (err, stats) ->
            if err or not stats.isFile()
              res.writeHead 403, 'Content-Type': 'text/html'
              res.end '<h1>403</h1><p>Forbidden</p>'
              return
            try
              code = coffee.compile fs.readFileSync(scriptName, "utf8")
              res.writeHead 200, {
                'Content-Type': mime.lookup(filename),
                'Content-Length': Buffer.byteLength code, "utf8"
              }
              res.end code
            catch e
              console.log "#{scriptName}: #{e.message}"
              res.writeHead 500, 'Content-Type': mime.lookup(filename)
              res.end "<h1>500</h1><p>Internal Server Error</p>"
            
    else
      fs.exists filename, handleFile
    
  
module.exports = InteractiveServer
