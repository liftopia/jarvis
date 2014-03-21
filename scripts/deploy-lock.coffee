# Description:
#   Deploy Locker
#
# Dependencies:
#   Underscore
#
# Configuration:
#   N/A
#
# Commands:
#   hubot I'm deploying <repo> <pr#> - Flag yourself as deploying something
#   hubot I'm really deploying <repo> <pr#> - Bypass the on deck deployer
#   hubot I'm next <repo> <pr#> - Flag yourself as deploying something soon
#   hubot I'm done deploying - Let jarvis know you're done
#   hubot who's next - Find out who's deploying next
#   hubot (all|list) deployers - List all deployers
#   hubot who's deploying - List all deployers
#   hubot remove active deploy - Remove the currently active deploy in case of disappearance
#   hubot cancel (my|<name>) deploys - Remove all deploys for target
#
# Author:
#   amdtech

_           = require 'underscore'

# Abstract Hubot brain
class Storage
  # Public: Constructor
  #
  # robot - hubot instance
  # namespace - the namespace for this storage instance
  #
  # Returns an instance
  constructor: (@robot, @namespace) ->
    @cache = {}
    @robot.brain.on 'loaded', =>
      if @robot.brain.data[@namespace]
        @cache = @robot.brain.data[@namespace]

  # Internal: Wraps a method in a save
  #
  # func - a function to wrap
  #
  # Returns nothing
  save_after: ->
    @robot.brain.data[@namespace] = @cache

  # Public: Stores a value at the given key
  #
  # key - a unique identifier
  # value - anything
  #
  # Returns nothing
  put: (key, value) ->
    @cache[key] = value
    @save_after()

  # Public: Gets the value at a specific key
  #
  # key - a key to search for
  #
  # Returns the value
  get: (key) ->
    @cache[key]

  # Public: Removes the value for a given key
  #
  # key - the key to remove
  #
  # Returns nothing
  remove: (key) ->
    delete @cache[key]
    @save_after

  # Public: Get all stored keys
  #
  # Returns an Array of keys
  keys: ->
    _.keys @cache

# A simple class to manage our deployers
class Deployers
  constructor: (@store) ->

  next: (repo, pull_request, user) ->
    deployers = @deployers()
    deployers.push { user: user, repo: repo, pull_request: pull_request }
    @store.put 'deployers', deployers

  on_deck: ->
    deployers = @deployers()
    deployers[0]

  activate: (repo, pull_request, user) ->
    on_deck = @on_deck()
    if on_deck is undefined
      @store.put 'active', { user: user, repo: repo, pull_request: pull_request }
      return true

    if on_deck.repo == repo && on_deck.pull_request == pull_request && on_deck.user.id == user.id
      deployers = @deployers()
      @store.put 'active', deployers[0]
      @store.put 'deployers', deployers.slice(1)
      true
    else
      false

  force: (repo, pull_request, user) ->
    deployer = { user: user, repo: repo, pull_request: pull_request }
    @store.put 'active', deployer
    @remove deployer

  remove: (deploy) ->
    deployers = @deployers()
    deployers_left = []
    for deployer in deployers
      unless deploy.user.id == deployer.user.id && deploy.repo == deployer.repo && deploy.pull_request == deployer.pull_request
        deployers_left.push deployer
    @store.put 'deployers', deployers_left

  active: ->
    @store.get('active') || undefined

  done: (user, force = false) ->
    active = @active()
    if active.user.id == user.id || force
      @store.remove('active')
      true
    else
      false

  count: ->
    deployers = @deployers()
    deployers.length

  clear: (user) ->
    deployers = @deployers()
    deployers_left = []
    for deployer in deployers
      unless user.id == deployer.user.id || user.name == deployer.user.name
        deployers_left.push deployer
    @store.put 'deployers', deployers_left

  deployers: ->
    @store.get('deployers') || []

# Internal: Get user's hipchat name from message
#
# message - Hubot message obj
#
# Returns a Hubot user
from_who = (message) ->
  message.message.user

# Add our new functionality to Hubot!
module.exports = (robot) ->
  # Deployers and store initialization
  deployer_store = new Storage robot, 'deployers'
  deployers      = new Deployers deployer_store

  # Nicely set up next deployment
  robot.respond /i(?:'m)?\s*deploy(?:ing)?\s*(\w+)[\s\/]+(\d+)/i, (msg) ->
    whom         = from_who msg
    repo         = msg.match[1]
    pull_request = msg.match[2]
    if deployers.activate repo, pull_request, whom
      msg.send whom.name + " is deploying " + msg.match[1] + "/" + msg.match[2]
    else
      on_deck = deployers.on_deck()
      msg.send "negative. " + on_deck.user.name + " (" + on_deck.repo + "/" + on_deck.pull_request + ") is next."

  # Bypass the next deployer
  robot.respond /i(?:'m)?\s*really\s+deploy(?:ing)?\s*(\w+)[\s\/]+(\d+)/i, (msg) ->
    whom         = from_who msg
    repo         = msg.match[1]
    pull_request = msg.match[2]

    active = deployers.active()
    next = deployers.on_deck()
    if active is undefined
      msg.send "ok " + whom.name + " you're bypassing " + next.name
      deployers.force repo, pull_request, whom
    else
      msg.send "sorry, " + active.user.name + " is currently deploying " + active.repo + "/" + active.pull_request

  # Add me to the list of deployers
  robot.respond /i(?:'m)?\s*next\s*(\w+)[\s\/]+(\d+)/i, (msg) ->
    whom         = from_who msg
    repo         = msg.match[1]
    pull_request = msg.match[2]

    try
      deployers.next repo, pull_request, whom
      msg.send whom.name + " wants to deploy " + msg.match[1] + "/" + msg.match[2] + ". You're #" + deployers.count() + "."
    catch error
      msg.send "I can't do that " + whom.name
      console.log "error adding new deployer"
      console.log error.stack

  # Remove my deploy
  robot.respond /i(?:'m)?\s*done\s*deploying$/i, (msg) ->
    whom = from_who msg
    if deployers.done whom
      msg.send whom.name + " is done deploying"
      on_deck = deployers.on_deck()
      unless on_deck is undefined
        msg.send on_deck.user.name + " is next with " + on_deck.repo + "/" + on_deck.pull_request + "!"
    else
      msg.send whom.name + " isn't currently deploying :-/"

  # Remove active deploy
  robot.respond /remove active deploy$/i, (msg) ->
    deployers.done whom, true
    msg.send "cleared active deploy"

  # Clear out all of someone's deploys
  robot.respond /cancel (.*) deploys$/i, (msg) ->
    whom = from_who msg
    target = msg.match[1]
    if target == 'my'
      deployers.clear whom
      msg.send whom.name + "'s deploys have been cleared"
    else
      target = { name: target }
      deployers.clear target
      msg.send target.name + "'s deploys have been cleared"

  # Get the next deployer's info
  robot.respond /who(?:'s)?\s*next[\!\?]*\s*$/i, (msg) ->
    whom = from_who msg
    try
      next = deployers.on_deck()
      if next is undefined
        msg.send "nobody's on deck"
      else
        msg.send next.user.name + " is deploying " + next.repo + "/" + next.pull_request + " next!"
    catch error
      msg.send "I can't do that " + whom.name
      console.log "error showing who's next"
      console.log error.stack

  # Show all the deployers waiting
  robot.respond /(?:(?:list|all)\s+deployers|who(?:'s)? deploying\??)$/i, (msg) ->
    whom = from_who msg
    try
      list    = deployers.deployers()
      active  = deployers.active()
      message = ""
      unless active is undefined
        message = message + " *** " + active.user.name + " is currently deploying " + active.repo + "/" + active.pull_request + "\n"
      if list.length == 0
        message = message + "nobody's on deck\n"
      else
        for next in list
          message = message + next.user.name + ": " + next.repo + "/" + next.pull_request + "\n"
      unless message == ""
        msg.send message.slice(0, -1) # strip off the last new line
    catch error
      msg.send "I can't do that " + whom.name
      console.log "error showing who's next"
      console.log error.stack

  # Some feedback on bad requests
  robot.respond /i(?:'m)?\s*next$/i, (msg) ->
    msg.send "You need to tell me what you want to deploy! (i'm next <repo> <pr#>)"

  # Some feedback on bad requests
  robot.respond /i(?:'m)?\s*next\s*(\w+)$/i, (msg) ->
    msg.send "You need to tell me the PR you're deploying! (i'm next " + msg.match[1] + " <pr#>)"

