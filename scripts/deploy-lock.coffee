# Description:
#   Deploy Locker
#
# Dependencies:
#   dateformat
#   fixed-array
#   githubot
#   Underscore
#
# Configuration:
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_USER
#   HUBOT_GITHUB_API
#   HUBOT_GITHUB_ORG
#   HUBOT_REPOS_LOOKUP
#
# Commands:
#   hubot I'm deploying <repo> <pr#> - Flag yourself as deploying something
#   hubot I'm really deploying <repo> <pr#> - Bypass the on deck deployer
#   hubot I'm next <repo> <pr#> - Flag yourself as deploying something soon
#   hubot I'm done deploying - Let jarvis know you're done
#   hubot who's next - Find out who's deploying next
#   hubot (all|list) deployers - List all deployers
#   hubot who's deploying - List all deployers
#   hubot deployment history - List the last deployments
#   hubot remove active deploy - Remove the currently active deploy in case of disappearance
#   hubot cancel (my|<name>) deploys - Remove all deploys for target
#
# Author:
#   amdtech

_          = require 'underscore'
FixedArray = require 'fixed-array'
dateFormat = require 'dateformat'
gh         = require('github')

github = new gh({ version: "3.0.0", protocol: "https" })
github.authenticate { type: "oauth", token: process.env.HUBOT_GITHUB_TOKEN }

default_github_user = process.env.HUBOT_GITHUB_USER

# borrowed from githubot
qualified_repo = (repo) ->
  return null unless repo?
  repo = repo.toLowerCase()
  return repo unless repo.indexOf("/") is -1
  return repo unless (user = default_github_user)?
  "#{user}/#{repo}"

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

clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime())

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()
  newInstance[key] = clone obj[key] for key of obj
  newInstance

# A simple class to manage our deployers
class Deployers
  constructor : (@store) ->

  active      : -> @store.get('active')
  count       : -> @manifests().length
  history     : -> @store.get 'history' || []
  manifests   : -> @store.get('manifests') || []
  on_deck     : -> @manifests()[0]

  next: (msg, manifest, callback) ->
    options      = clone manifest.github_options
    options.body = "@#{manifest.user.githubLogin} is deploying this soon."

    github.issues.createComment options, (err, comment) =>
      return if @handle_error(msg, "Issue posting comment", err)?

      manifests = @manifests()

      manifests.push manifest
      @store.put 'manifests', manifests

      callback?(comment)

  activate: (msg, manifest, callback) ->
    active  = @active()
    on_deck = @on_deck()

    if active?
      callback?(false)
    else
      options      = clone manifest.github_options
      options.body = "@#{manifest.user.githubLogin} is deploying this now."

      if not on_deck?
        github.issues.createComment options, (err, comment) =>
          return if @handle_error(msg, "Issue posting comment", err)?

          @store.put 'active', manifest
          callback?(comment)
      else if on_deck.user.id == manifest.user.id && on_deck.slug == manifest.slug
        github.issues.createComment options, (err, comment) =>
          return if @handle_error(msg, "Issue posting comment", err)?

          manifests = @manifests()
          @store.put 'manifests', manifests.slice(1)
          @store.put 'active', manifest
          callback?(comment)

  force: (msg, manifest, callback) ->
    options      = clone manifest.github_options
    options.body = "@#{manifest.user.githubLogin} is forcibly deploying this now."

    github.issues.createComment options, (err, comment) =>
      return if @handle_error(msg, "Issue posting comment", err)?

      @store.put 'active', manifest
      @remove manifest
      callback?(comment)

  remove: (manifest) ->
    manifests      = @manifests()
    manifests_left = []

    for man in manifests
      unless man.user.id == manifest.user.id && man.slug == manifest.slug
        manifests_left.push man

    @store.put 'manifests', manifests_left

  done: (msg, user, callback) =>
    active = @active()
    if active?.user.id == user.id
      options      = clone active.github_options
      options.body = "@#{active.user.githubLogin} has finished deploying."

      github.issues.createComment options, (err, comment) =>
        return if @handle_error(msg, "Issue posting comment", err)?

        @store.remove('active')
        @track active
        callback?(active)
    else
      callback?(false)

  track: (active) ->
    history = FixedArray(100, @history())
    history.push active
    @store.put 'history', history.array

  remove_active: (msg, user, callback) ->
    active       = @active()

    options      = clone active.github_options
    options.body = "@#{user.githubLogin} canceled this deploy."

    github.issues.createComment options, (err, comment) =>
      return if @handle_error(msg, "Issue posting comment", err)?

      @store.remove('active')
      callback?(active)

  topic: ->
    messages = []
    active   = @active()
    on_deck  = @on_deck()

    messages.push "Active: #{active.user.name} - #{active.slug}"    if active
    messages.push "On Deck: #{on_deck.user.name} - #{on_deck.slug}" if on_deck

    messages.push "Deploy Queue Open" if _.isEmpty(messages)

    messages.join ' / '

  clear: (msg, user, callback) ->
    manifests = @manifests()
    manifests_left = []

    for manifest in manifests
      if user.id == manifest.user.id
        options      = clone manifest.github_options
        options.body = "This deploy has been canceled."

        github.issues.createComment options, (err, comment) =>
          return if @handle_error(msg, "Issue posting comment", err)?

          callback?(manifest)
      else
        manifests_left.push manifest

    @store.put 'manifests', manifests_left

  handle_error: (msg, message, err) ->
    if err?
      msg.send "#{message}: #{JSON.parse(err).message}"
      true

  # Internal: Collect the information needed to track
  #
  # msg - Hubot message object
  # repo - Repository slug
  # pull_request - The Github PR ID
  #
  # Returns a manifest object
  manifest_from: (msg, repo, pull_request, opts = {}, callback) ->
    user = from_who msg
    unless user.githubLogin?
      msg.reply "You need to set your github login (#{robot.mention_name || robot.name} i am <github username>)"
      return

    now = Date.now()

    options =
      number : pull_request
      repo   : repo
      user   : default_github_user

    github.pullRequests.get options, (err, pull) =>
      return if @handle_error(msg, "Issue getting pull request", err)?

      github.issues.getComments options, (err, comments) =>
        return if @handle_error(msg, "Issue getting comments", err)?

        unless opts.force?
          _.each comments, (comment) ->
            if comment.user.login != pull.user.login
              deploy_approved = true  if /:grapes:/.test comment.body
              deploy_approved = false if /:lemon:/.test comment.body
          unless deploy_approved
            msg.reply "You don't have grapes yet..."
            return

        manifest =
          branch         : pull.head.ref
          githubLogin    : pull.user.login
          github_options : options
          human_time     : "#{dateFormat(now)}"
          pull_request   : pull_request
          repo           : repo
          slug           : "#{repo}/#{pull_request}"
          timestamp      : now
          url            : "https://github.com/#{default_github_user}/#{repo}/pull/#{pull_request}"
          user           : user

        console.log "Manifest created for #{manifest.user.name} : #{manifest.slug}"
        callback?(manifest)

# Internal: Get user's hipchat name from message
#
# message - Hubot message obj
#
# Returns a Hubot user
from_who = (message) ->
  message.message.user

# Add our new functionality to Hubot!
module.exports = (robot) ->
  release_url     = process.env.JENKINS_RELEASE_URL
  production_job  = process.env.JENKINS_PRODUCTION_JOB
  repos           = {}

  _.each process.env.HUBOT_REPOS_LOOKUP?.split(','), (details) ->
    [ name, param ] = details.split(':')
    repos[name]     = param

  # Deployers and store initialization
  deployer_store  = new Storage robot, 'deployers'
  deployers       = new Deployers deployer_store

  # Basic error handling for logging and notification of errors
  robot.error (err, msg) ->
    robot.logger.error err.stack
    msg?.reply "Whoops... check #{robot.name}'s logs :("

  getAmbiguousUserText = (users) ->
    "Be more specific, I know #{users.length} people named like that: #{(user.name for user in users).join(", ")}"

  # Nicely set up next deployment
  robot.respond /i(?:'m)?\s*deploy(?:ing)?\s*([\w\.]+)[\s\/]+(\d+)/i, (msg) ->
    deployers.manifest_from msg, msg.match[1], msg.match[2], { force: false }, (manifest) ->
      deployers.activate msg, manifest, (activated) ->
        if activated
          msg.send "Deploying #{manifest.slug} - Branch: #{manifest.branch}"
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
    deployers.manifest_from msg, msg.match[1], msg.match[2], { force: true }, (manifest) ->
      active  = deployers.active()
      on_deck = deployers.on_deck()

      if active?
        msg.reply "Sorry, #{active.user.name} is currently deploying #{active.slug}."
      else
        msg.reply "Ok, you're bypassing #{on_deck.user.name}." if on_deck?

        deployers.force msg, manifest, (issue) ->
          msg.send "Deploy bypass active, #{manifest.user.name} has jumped the gun with #{manifest.slug}."
          robot.emit 'deploy-lock:deploying', { manifest: manifest, msg: msg }

  # Add me to the list of deployers
  robot.respond /i(?:'m)?\s*next\s*([\w\.]+)[\s\/]+(\d+)/i, (msg) ->
    deployers.manifest_from msg, msg.match[1], msg.match[2], { force: false }, (manifest) ->
      deployers.next msg, manifest, (issue) ->
        msg.reply "You want to deploy #{manifest.slug}. You're ##{deployers.count()}."
        robot.emit 'deploy-lock:next', { manifest: manifest, msg: msg }

  # Remove my deploy
  robot.respond /i(?:'m)?\s*done\s*deploying$/i, (msg) ->
    whom = from_who msg

    deployers.done msg, whom, (manifest) ->
      if manifest?
        robot.emit 'deploy-lock:done', { manifest: manifest, msg: msg }

        on_deck = deployers.on_deck()
        if on_deck
          prepend = ''
          prepend = '@' if on_deck.user.mention_name?
          mention = "#{prepend}#{on_deck.user.mention_name || on_deck.user.name}"
          msg.send "#{mention} is next (jarvis i'm deploying #{on_deck.slug})"
        else
          msg.send "Nobody's on deck!  Let's get some code out peeps ;)"
      else
        msg.reply "You aren't currently deploying :-/"

  # Remove active deploy
  robot.respond /remove active deploy$/i, (msg) ->
    whom   = from_who msg
    active = deployers.active()

    unless active?
      msg.reply "There's nothing being deployed right now."
      return

    unless whom.githubLogin?
      msg.reply "You need to set your github login (#{robot.mention_name || robot.name} i am <github username>)"
      return

    deployers.remove_active msg, whom, (manifest) =>
      robot.emit 'deploy-lock:active-cleared', { manifest: manifest, msg: msg } if manifest?
      msg.reply "Cleared active deploy"

  # Clear out all of someone's deploys
  robot.respond /cancel (.*) deploys$/i, (msg) ->
    whom = from_who msg
    target = msg.match[1]
    mention = "Your"

    if target == 'my'
      target = whom
    else
      users = robot.brain.usersForFuzzyName(target)
      if users.length is 1
        target = users[0]
      else if users.length > 1
        msg.send getAmbiguousUserText users
        return
      else
        msg.send "#{target}? Never heard of 'em"
        return

      mention = "#{target.name}'s"

    deployers.clear msg, target, (manifest) =>
      msg.reply "#{manifest.user.name}'s #{manifest.slug} deploy has been canceled."
      robot.emit 'deploy-lock:cleared', { manifest: manifest, msg: msg }

  # Get the history
  robot.respond /deployment history$/i, (msg) ->
    history = deployers.history()

    messages = []
    for manifest in history.slice(0).reverse()
      timestamp = manifest.human_time
      timestamp ?= "No Timestamp"

      content = [
        timestamp,
        manifest.url,
        manifest.user.githubLogin,
        manifest.branch
      ]

      messages.push content.join ' | '

    msg.send messages.join("\n")

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

  topic_handler = (details) ->
    msg = details.msg

    robot.emit 'update-topic', { msg: msg, topic: deployers.topic(), component: 'deployers' }

  robot.on 'deploy-lock:deploying', (details) ->
    manifest                     = details.manifest
    msg                          = details.msg
    params                       = {}
    params[repos[manifest.repo]] = manifest.branch
    params["Confirmed"]          = "true"

    if manifest.user.githubLogin == manifest.githubLogin
      robot.emit 'jenkins:build', production_job, params, msg
    else
      msg.reply "That's not your pull request. To manually deploy, go to #{release_url}."

    topic_handler details

  robot.on 'deploy-lock:next', (details) ->
    topic_handler details

  robot.on 'deploy-lock:done', (details) ->
    topic_handler details

  robot.on 'deploy-lock:active-cleared', (details) ->
    topic_handler details

  robot.on 'deploy-lock:cleared', (details) ->
    topic_handler details
