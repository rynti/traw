tty = require "tty"
events = require "events"

class ShutdownHandler extends events.EventEmitter
  constructor: ->
    process.on "SIGINT", => @emit "exit"

    if process.stdin?
      process.stdin.setRawMode? true
      process.stdin.resume?()

      process.stdin.on? "data", (input) =>
        @emit "exit" if b is 0x03 for b in input
  

module.exports = ShutdownHandler
