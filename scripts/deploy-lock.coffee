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

  next: (manifest) ->
    manifests = @manifests()

    manifests.push manifest
    @store.put 'manifests', manifests

  on_deck: ->
    @manifests()[0]

  activate: (manifest) ->
    active = @active()
    on_deck = @on_deck()

    unless active?
      if not on_deck?
        @store.put 'active', manifest
      else if _.isEqual(on_deck, manifest)
        manifests = @manifests()
        @store.put 'manifests', manifests.slice(1)
        @store.put 'active', manifest

  force: (manifest) ->
    @store.put 'active', manifest
    @remove manifest

  remove: (manifest) ->
    manifests      = @manifests()
    manifests_left = []

    for man in manifests
      unless _.isEqual(man, manifest)
        manifests_left.push man

    @store.put 'manifests', manifests_left

  active: ->
    @store.get('active')

  done: (user, force = false) ->
    active = @active()
    if active && (active.user.id == user.id || force)
      @store.remove('active')
      active
    else
      false

  topic: ->
    messages = []
    active = @active()
    on_deck = @on_deck()

    messages.push "Active: #{active.user.name} - #{active.slug}"    if active
    messages.push "On Deck: #{on_deck.user.name} - #{on_deck.slug}" if on_deck

    messages.push "Deploy Queue Open" if _.isEmpty(messages)

    messages.join(' / ')

  count: ->
    @manifests().length

  clear: (user) ->
    manifests = @manifests()
    manifests_left = []
    for manifest in manifests
      unless user.id == manifest.user.id || user.name == manifest.user.name
        manifests_left.push manifest
    @store.put 'manifests', manifests_left

  manifests: ->
    @store.get('manifests') || []

# Internal: Get user's hipchat name from message
#
# message - Hubot message obj
#
# Returns a Hubot user
from_who = (message) ->
  message.message.user

# Internal: Collect the information needed to track
#
# msg - Hubot message object
# repo - Repository slug
# pull_request - The Github PR ID
#
# Returns a manifest object
# TODO: (amdtech) probably replace with class
manifest_from = (msg, repo, pull_request) ->
  user        : from_who msg
  repo        : repo
  pull_request: pull_request
  slug        : "#{repo}/#{pull_request}"
  url         : "https://github.com/liftopia/#{repo}/pull/#{pull_request}"

# Add our new functionality to Hubot!
module.exports = (robot) ->
  # Deployers and store initialization
  deployer_store = new Storage robot, 'deployers'
  deployers      = new Deployers deployer_store

  # Basic error handling for logging and notification of errors
  robot.error (err, msg) ->
    robot.logger.error err.stack
    msg.reply "Whoops... check #{robot.name}'s logs :(" if msg?

  # Nicely set up next deployment
  robot.respond /i(?:'m)?\s*deploy(?:ing)?\s*([\w\.]+)[\s\/]+(\d+)/i, (msg) ->
    manifest = manifest_from msg, msg.match[1], msg.match[2]

    if deployers.activate manifest
      msg.send "Deploying #{manifest.slug}"
      robot.emit 'deploy-lock:deploying', { manifest: manifest, msg: msg }
    else
      on_deck = deployers.on_deck()
      active = deployers.active()
      if active?
        msg.send "Negative. #{active.user.name} is currently deploying #{active.slug}."
      else
        msg.send "Negative. #{on_deck.user.name} is deploying #{on_deck.slug} next."

  # Bypass the next deployer
  robot.respond /i(?:'m)?\s*really\s+deploy(?:ing)?\s*([\w\.]+)[\s\/]+(\d+)/i, (msg) ->
    manifest = manifest_from msg, msg.match[1], msg.match[2]
    active   = deployers.active()
    on_deck  = deployers.on_deck()

    if active
      msg.reply "Sorry, #{active.user.name} is currently deploying #{active.slug}."
    else
      msg.reply "Ok, you're bypassing #{on_deck.user.name}." if on_deck
      deployers.force manifest
      msg.send "Deploy bypass active, #{manifest.user.name} has jumped the gun with #{manifest.slug}."
      robot.emit 'deploy-lock:deploying', { manifest: manifest, msg: msg }

  # Add me to the list of deployers
  robot.respond /i(?:'m)?\s*next\s*([\w\.]+)[\s\/]+(\d+)/i, (msg) ->
    manifest = manifest_from msg, msg.match[1], msg.match[2]

    deployers.next manifest
    msg.reply "You want to deploy #{manifest.slug}. You're ##{deployers.count()}."
    robot.emit 'deploy-lock:next', { manifest: manifest, msg: msg }

  # Remove my deploy
  robot.respond /i(?:'m)?\s*done\s*deploying$/i, (msg) ->
    whom     = from_who msg
    manifest = deployers.done whom

    if manifest
      robot.emit 'deploy-lock:done', { manifest: manifest, msg: msg }

      on_deck = deployers.on_deck()
      if on_deck
        msg.send "#{on_deck.user.name} is next with #{on_deck.slug}!"
      else
        msg.send "Nobody's on deck!  Let's get some code out peeps ;)"
    else
      msg.reply "You aren't currently deploying :-/"

  # Remove active deploy
  robot.respond /remove active deploy$/i, (msg) ->
    whom     = from_who msg
    manifest = deployers.done whom, true

    robot.emit 'deploy-lock:active-cleared', { manifest: manifest, msg: msg } if manifest
    msg.reply "Cleared active deploy"

  # Clear out all of someone's deploys
  robot.respond /cancel (.*) deploys$/i, (msg) ->
    whom = from_who msg
    target = msg.match[1]

    if target == 'my'
      deployers.clear whom
      msg.reply "Your deploys have been cleared"
      robot.emit 'deploy-lock:cleared', { manifest: {}, msg: msg }
    else
      target = { name: target }
      deployers.clear target
      msg.reply "#{target.name}'s deploys have been cleared"
      robot.emit 'deploy-lock:cleared', { manifest: {}, msg: msg }

  # Get the next deployer's info
  robot.respond /who(?:'s)?\s*next[\!\?]*\s*$/i, (msg) ->
    next = deployers.on_deck()

    if next
      msg.reply "#{next.user.name} is deploying #{next.slug} next!"
    else
      msg.reply "Nobody's on deck"

  # Show all the deployers waiting
  robot.respond /(?:(?:list|all)\s+deployers|who(?:'s)? deploying\??)$/i, (msg) ->
    list     = deployers.manifests()
    active   = deployers.active()
    messages = []

    if active
      messages.push " *** #{active.user.name} is currently deploying #{active.slug}"
    if list.length == 0
      messages.push "Nobody's on deck!"
    else
      messages.push "#{next.user.name}: #{next.slug}" for next in list

    msg.send messages.join("\n")

  # Some feedback on bad requests
  robot.respond /i(?:'m)?\s*next$/i, (msg) ->
    msg.send "You need to tell me what you want to deploy! (i'm next <repo> <pr#>)"

  # Some feedback on bad requests
  robot.respond /i(?:'m)?\s*next\s*([\w\.]+)$/i, (msg) ->
    msg.send "You need to tell me the PR you're deploying! (i'm next " + msg.match[1] + " <pr#>)"

  topic_handler = (event) ->
    msg = event.msg

    robot.emit 'update-topic', { msg: msg, topic: deployers.topic(), component: 'deployers' }

  robot.on 'deploy-lock:deploying', (event) ->
    topic_handler event

  robot.on 'deploy-lock:next', (event) ->
    topic_handler event

  robot.on 'deploy-lock:done', (event) ->
    topic_handler event

  robot.on 'deploy-lock:active-cleared', (event) ->
    topic_handler event

  robot.on 'deploy-lock:cleared', (event) ->
    topic_handler event

  # Get the topic and do stuff with it
  robot.topic (msg) ->
    topic   = msg.message.text.split('/', 2)[1]
    active  = deployers.active()
    on_deck = deployers.on_deck()

    if active
      deploy_text = "Current Deployer: #{active.user.name} - Deploying: #{active.slug} "
    else if on_deck
      deploy_text = "Next Deployer: #{on_deck.user.name} - Deploying: #{on_deck.slug} "
    else
      deploy_text = "Nobody on deck! "

    console.log([ deploy_text, topic ].join('/'))
