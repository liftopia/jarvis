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
#   hubot deploy failed - Mark the deploy as failed in stathat
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
  constructor : (@robot, @namespace) ->

  active      : -> @robot.storage.get(@namespace, 'active')
  count       : -> @manifests().length
  history     : -> @robot.storage.get(@namespace, 'history')   || []
  manifests   : -> @robot.storage.get(@namespace, 'manifests') || []
  on_deck     : -> @manifests()[0]

  push: (manifest) ->
    manifests = @manifests()

    manifests.push manifest
    @robot.storage.put @namespace, 'manifests', manifests

  notify: (msg, manifest, body) ->
    return false if manifest.branch == 'master'

    options      = clone manifest.github_options
    options.body = body
    robot.emit 'github:issues:createComment', msg, options

  next: (msg, manifest, callback) ->
    @notify msg, manifest, "@#{manifest.user.githubLogin} is deploying this soon."

    @push manifest
    callback?()

  activate: (msg, manifest, callback) ->
    active  = @active()
    on_deck = @on_deck()

    if active?
      callback?(false)
    else
      body = "@#{manifest.user.githubLogin} is deploying this now."
      if not on_deck?
        @notify msg, manifest, body

        @robot.storage.put @namespace, 'active', manifest
        callback?(true)
      else if on_deck.user.id == manifest.user.id && on_deck.slug == manifest.slug
        @notify msg, manifest, body

        manifests = @manifests()
        @robot.storage.put @namespace, 'manifests', manifests.slice(1)
        @robot.storage.put @namespace, 'active', manifest

        callback?(true)

  force: (msg, manifest, callback) ->
    @notify msg, manifest, "@#{manifest.user.githubLogin} is forcibly deploying this now."

    @robot.storage.put @namespace, 'active', manifest
    @remove manifest
    callback?()

  remove: (manifest) ->
    manifests      = @manifests()
    manifests_left = []

    for man in manifests
      unless man.user.id == manifest.user.id && man.slug == manifest.slug
        manifests_left.push man

    @robot.storage.put @namespace, 'manifests', manifests_left

  done: (msg, user, callback) =>
    active = @active()
    if active?.user.id == user.id
      @notify msg, active, "@#{active.user.githubLogin} has finished deploying."

      @robot.storage.remove @namespace, 'active'
      @merge msg, active
      @track active
      callback?(active)
    else
      callback?(false)

  merge: (msg, active) ->
    return false if active.branch == 'master'

    options = clone active.github_options
    options.branch = active.branch
    robot.emit 'github:pullRequests:merge', msg, options

  track: (active) ->
    history = FixedArray(100, @history())
    history.push active
    @robot.storage.put @namespace, 'history', history.array

  remove_active: (msg, user, callback) ->
    active       = @active()

    @notify msg, active, "@#{user.githubLogin} canceled this deploy."

    @robot.storage.remove @namespace, 'active'
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
    manifests      = @manifests()
    manifests_left = []

    for manifest in manifests
      if user.id == manifest.user.id
        @notify msg, manifest, "This deploy has been canceled."

        callback?(manifest)
      else
        manifests_left.push manifest

    @robot.storage.put @namespace, 'manifests', manifests_left

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

    if pull_request == 'master'
      options.base = 'master'
      options.head = 'master'

      manifest =
        branch         : options.head
        githubLogin    : user.githubLogin
        github_options : options
        human_time     : "#{dateFormat(now)}"
        pull_request   : pull_request
        repo           : repo
        slug           : "#{repo}/#{pull_request}"
        timestamp      : now
        test_plan      : undefined
        url            : "https://github.com/#{default_github_user}/#{repo}/tree/master"
        user           : user

      console.log "Manifest created for #{manifest.user.name} : #{manifest.slug}"
      callback?(manifest)
    else
      github.pullRequests.get options, (err, pull) =>
        return if @handle_error(msg, "Issue getting pull request", err)?

        if opts.verify && user.githubLogin != pull.user.login
          msg.reply "That's not your pull request."
          return

        options.base = "master"
        options.head = pull.head.ref

        github.repos.compareCommits options, (err, commits) =>
          return if @handle_error(msg, "Issue comparing commits", err)?

          if opts.deploying && commits.status is not "ahead"
            if commits.status is "identical"
              msg.reply "Your branch is identical to master, did you forget to push something?"
            else if commits.status is "diverged"
              msg.reply "Your branch has diverged from master, you'll need to rebase on master."
            else
              msg.reply "Your branch is #{commits.status} master, please rebase on master."

            return

          github.issues.getComments options, (err, comments) =>
            return if @handle_error(msg, "Issue getting comments", err)?

            deploy_approved = false
            qa_approved     = false
            plan            = get_plan pull.body

            _.each comments, (comment) ->
              new_plan = get_plan comment
              plan     = new_plan if new_plan?

              unless opts.force
                if comment.user.login != pull.user.login
                  deploy_approved = true  if /:grapes:/.test comment.body
                  deploy_approved = false if /:lemon:/.test comment.body

                  qa_approved = true  if /:cake:/.test comment.body
                  qa_approved = false if /:corn:/.test comment.body

            unless opts.force
              unless deploy_approved
                msg.reply "You don't have grapes yet..."
                return

              unless qa_approved
                msg.reply "You don't have cake yet..."
                return

            manifest =
              branch         : options.head
              githubLogin    : pull.user.login
              github_options : options
              human_time     : "#{dateFormat(now)}"
              pull_request   : pull_request
              repo           : repo
              slug           : "#{repo}/#{pull_request}"
              timestamp      : now
              test_plan      : plan
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

# Internal: Verify presence of qa section, and return the plan if so
#
# string - String to check
#
# Returns a qa plan if found
get_plan = (string) ->
  in_qa = false
  plan = []

  if /```qa/.test string
    _.each string.split(/\r?\n/), (line) ->
      if in_qa
        if line is '```'
          in_qa = false
        else
          plan.push line
      else
        in_qa = true if line is '```qa'

  plan.join('\n') if plan.length > 0

# Add our new functionality to Hubot!
module.exports = (robot) ->
  release_url     = process.env.JENKINS_RELEASE_URL
  rtopia_job      = 'ReleaseRtopia'
  cloudstore_job  = 'DeployCloudstoreClient'
  core_job        = 'DeployCoreClient'
  repos           = {}

  _.each process.env.HUBOT_REPOS_LOOKUP?.split(','), (details) ->
    [ name, param ] = details.split(':')
    repos[name]     = param

  # Deployers and store initialization
  deployers       = new Deployers robot, 'deployers'

  # Basic error handling for logging and notification of errors
  robot.error (err, msg) ->
    robot.logger.error err.stack
    msg?.reply "Whoops... check #{robot.name}'s logs :("

  getAmbiguousUserText = (users) ->
    "Be more specific, I know #{users.length} people named like that: #{(user.name for user in users).join(", ")}"

  # Nicely set up next deployment
  robot.respond /i(?:[’']?m)?\s+deploy(?:ing)?\s+(\S+)\/(\d+|master)/i, (msg) ->
    msg.match[1] = msg.match[1].replace(/https?:\/\//, '')
    deployers.manifest_from msg, msg.match[1], msg.match[2], { deploying: true, force: false, verify: true }, (manifest) ->
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
  robot.respond /i(?:[’']?m)?\s+really\s+deploy(?:ing)?\s+(\S+)\/(\d+|master)/i, (msg) ->
    msg.match[1] = msg.match[1].replace(/https?:\/\//, '')
    deployers.manifest_from msg, msg.match[1], msg.match[2], { deploying: true, force: true, verify: false }, (manifest) ->
      active  = deployers.active()
      on_deck = deployers.on_deck()

      if active?
        msg.reply "Sorry, #{active.user.name} is currently deploying #{active.slug}."
      else
        msg.reply "Ok, you're bypassing #{on_deck.user.name}." if on_deck?

        deployers.force msg, manifest, () ->
          msg.send "Deploy bypass active, #{manifest.user.name} has jumped the gun with #{manifest.slug}."
          robot.emit 'deploy-lock:deploying', { manifest: manifest, msg: msg }

  # Add me to the list of deployers
  robot.respond /i(?:[’']?m)?\s+next\s+(\S+)\/(\d+|master)/i, (msg) ->
    msg.match[1] = msg.match[1].replace(/https?:\/\//, '')
    deployers.manifest_from msg, msg.match[1], msg.match[2], { deploying: false, force: false, verify: true }, (manifest) ->
      deployers.next msg, manifest, () ->
        msg.reply "You want to deploy #{manifest.slug}. You're ##{deployers.count()}."
        robot.emit 'deploy-lock:next', { manifest: manifest, msg: msg }

  # Remove my deploy
  robot.respond /i(?:[’']?m)?\s+done\s+deploying$/i, (msg) ->
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
    if _.isEmpty(history)
      messages.push 'No deployment history!'

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
  robot.respond /who(?:[’']?s)?\s+next[\!\?\s]*$/i, (msg) ->
    next = deployers.on_deck()

    if next
      msg.reply "#{next.user.name} is deploying #{next.slug} next!"
    else
      msg.reply "Nobody's on deck"

  # Show all the deployers waiting
  robot.respond /(?:(?:list|all)\s+deployers|who(?:[’']?s)? deploying\??)$/i, (msg) ->
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
  robot.respond /i(?:[’']?m)?\s*next$/i, (msg) ->
    msg.send "You need to tell me what you want to deploy! (i'm next <repo> <pr#>)"

  # Some feedback on bad requests
  robot.respond /i(?:[’']?m)?\s*next\s*([\w\.]+)$/i, (msg) ->
    msg.send "You need to tell me the PR you're deploying! (i'm next " + msg.match[1] + " <pr#>)"

  robot.respond /deploy failed/i, (msg) ->
    active   = deployers.active()
    history  = deployers.history()

    if active?
      msg.send "Active deploy marked as failed."
      robot.emit 'stathat:mark:deployFailed', active, msg
    else
      msg.send "Marking last deploy as failed."
      robot.emit 'stathat:mark:deployFailed', history.slice(0).reverse()[0], msg


  topic_handler = (details) ->
    msg = details.msg

    robot.emit 'update-topic', { msg: msg, topic: deployers.topic(), component: 'deployers' }

  robot.on 'deploy-lock:deploying', (details) ->
    manifest                     = details.manifest
    msg                          = details.msg
    params                       = {}
    params[repos[manifest.repo]] = manifest.branch
    params["Confirmed"]          = "true"
    params['REPO']               = manifest.repo

    if manifest.repo == 'ptopia' || manifest.repo == 'piggy_bank'
      robot.emit 'rundeck:run', manifest, msg
    else if manifest.repo == 'rtopia'
      robot.emit 'jenkins:build', rtopia_job, params, msg
    else if manifest.repo == 'cloudstore_client'
      robot.emit 'jenkinsio:build', cloudstore_job, params, msg
    else # core_client
      robot.emit 'jenkinsio:build', core_job, params, msg

    topic_handler details

  robot.on 'deploy-lock:next', (details) ->
    topic_handler details

  robot.on 'deploy-lock:done', (details) ->
    topic_handler details

  robot.on 'deploy-lock:active-cleared', (details) ->
    topic_handler details

  robot.on 'deploy-lock:cleared', (details) ->
    topic_handler details
