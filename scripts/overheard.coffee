# Description:
#   Quotes overheard
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   Rob said 'phrase' (context)
#   quote me - show random quote
#   quotes - show all quotes
#   quotes clear - delete all quotes in the system
#
# Author:
#   jmacadam

sassy_confirmations = [
  "Srsly? woa.",
  "nice one",
  "lame",
  "said WHAT?",
  "maybe we should call for help...",
  "I'll never forget that one"
]

class Quotes
  constructor: (@robot) ->
    @robot.brain.on 'loaded', =>
      @cache = @robot.brain.data.quotes
      @cache = [] unless @cache

  add: (who, what, context) ->
    if context?
      quote = "#{who} said #{what} (#{context})"
    else
      quote = "#{who} said #{what}"

    @cache.push {quote: quote, who: who, what: what, context: context}
    @robot.brain.data.quotes = @cache

  list: ->
    @cache.reduce (a, b) -> "#{a['quote']}\n#{b['quote']}"

  randomQuote: ->
    @cache[Math.floor(Math.random() * @cache.length)]['quote']

  clear: ->
    @cache = []
    @robot.brain.data.quotes = @cache

module.exports = (robot) ->
  quotes = new Quotes(robot)
  robot.respond /(.+) said "([^"]+)"$/i, (msg) ->
    quotes.add(msg.match[1], msg.match[2])
    msg.send msg.random sassy_confirmations

  robot.respond /(.+) said "([^"]+)"(?:\s\(([^\)]+)\))/i, (msg) ->
    quotes.add(msg.match[1], msg.match[2], msg.match[3])
    msg.send msg.random sassy_confirmations

  robot.respond /quote me/i, (msg) ->
    msg.send quotes.randomQuote()

  robot.respond /quotes$/i, (msg) ->
    msg.send quotes.list()

  robot.respond /quotes clear$/i, (msg) ->
    quotes.clear()
    msg.send "What quotes?"
