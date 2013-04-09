fs = require "fs"
chokidar = require "chokidar"
events = require "events"

class ManagedJSON extends events.EventEmitter
  constructor: (@filename, callback) ->
    @on "update", callback if callback?

    @watcher = chokidar.watch @filename
    @watcher.on "add", @update
    @watcher.on "change", @update

  update: =>
    fs.readFile @filename, "utf8", (err, content) =>
      @data = JSON.parse content if not err?
      @emit "update", err


  
module.exports = ManagedJSON
