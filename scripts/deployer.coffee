# Description:
#   Feature branch deployments
#
# Dependencies:
#   Querystring
#   Underscore
#   ScopedHttpClient
#
# Configuration:
#   HUBOT_JENKINS_URL
#   HUBOT_JENKINS_AUTH
#
# Commands:
#   hubot I'm watching <hostname> - Receive a notification anytime this host is deployed
#   hubot I watch <hostname> - Receive a notification anytime this host is deployed
#   hubot forget <hostname> - No longer receive notifications for these deployments
#   hubot deploy <hostname> <repo/branch> <repo/branch> - Deploy a custom branch server
#   hubot deploy failed - A production deployment failed, so track it
#   hubot redeploy <hostname> - Re-trigger the last known deployment for this host
#   hubot destroy <hostname> - Destroy the server
#
# Author:
#   doomspork

querystring = require 'querystring'
_           = require 'underscore'
http        = require 'scoped-http-client'

STAGING_DOMAIN = 'liftopia.net'

# Internal: Convert an environment name to an http url
#
# hostname - the environment's name
#
# Returns a string
feature_url = (hostname) ->
  "http://#{hostname}.#{STAGING_DOMAIN}"

# Internal: Convert a hostname to an ssh url
#
# hostname - the server's hostname
#
# Returns a string
ssh_url = (hostname) ->
  "ssh://#{hostname}"

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

# A simple class to manage our deployment spectators
class Spectators
  constructor: (@store) ->

  # Public: Add a user to the list of spectators for a hostname
  #
  # hostname - the hostname to watch
  # user - the user chat name
  #
  # Returns nothing
  watch: (hostname, user) ->
    watchers = @watching hostname
    if watchers.indexOf(user.id) == -1
      watchers.push user.id
      @store.put hostname, watchers

  # Public: Remove a user from the list of spectators for a hostname
  #
  # hostname - the hostname to forget
  # user - the user chat name
  #
  # Returns nothing
  forget: (hostname, user) ->
    watchers = @watching hostname
    index = watchers.indexOf user.id
    if index >= 0
      delete watchers[index]
      @store.put hostname, watchers

  # Public: Get the list of spectators
  #
  # hostname - the hostname to get spectators for
  #
  # Returns an Array of user names
  watching: (hostname) ->
    @store.get(hostname) || []

  # Public: Clears the spectators for a hostname
  #
  # hostname - the hostname to empty
  #
  # Returns nothing
  clear: (hostname) ->
    @store.remove hostname

class Jenkins
  # Public: Constructor
  #
  # robot - Hubot instance
  #
  # Returns a new Jenkins instance
  constructor: (@robot) ->
    @url = process.env.HUBOT_JENKINS_URL

  # Public: Request a deployment
  #
  # parameters - an hash of key/value pairs to use as GET params
  # callback - a callback method for the HTTP request
  #
  # Returns nothing
  deploy: (parameters, callback) ->
    @run_job 'VagrantBranchDeploy', parameters, callback

  # Public: Request a redeployment
  #
  # parameters - an hash of key/value pairs to use as GET params
  # callback - a callback method for the HTTP request
  #
  # Returns nothing
  redeploy: (parameters, callback) ->
    @run_job 'VagrantBranchRedeploy', parameters, callback

  # Public: Destroy the deployment at a particular hostname
  #
  # hostname - a hostname
  # callback - a callback for HTTP requests
  #
  # Returns nothing
  destroy: (hostname, callback) ->
    @run_job 'VagrantBranchDestroy', {'NODE_NAME': hostname}, callback

  # Public: Run a job on Jenkins
  #
  # job - The job name
  # parameters - the GET parameters as key/value pairs
  # callback - a HTTP callback
  #
  # Returns nothing
  run_job: (job, parameters, callback) ->
    safe_params = @safe_url_params parameters

    console.log "Jenkins #{job} triggered with #{safe_params}"

    request = http.create(@url)
      .path("job/#{job}/buildWithParameters?token=dfc0b2ead4a57bc60097286eec01a336&#{safe_params}")
      .header('Content-Length', 0)

    request.post() callback

  # Internal: Generate a transaction key
  #
  # Returns a unique key
  transaction_key: ->
    Date.now()

  # Internal: Make key/value paramaters URL safe
  #
  # parameters - key/value pairs
  #
  # Returns a URL safe string of parameters
  safe_url_params: (parameters) ->
    querystring.stringify parameters

# Internal: Branch defaults for rtopia and liftopia.com
defaults =
  'liftopia.com': 'master'
  'piggy_bank':   'master'
  'rtopia':       'master'

# Internal: Create a unique host name
#
# grouped_matches - Hubot matches as an object
#
# Returns a host name as a String
create_host_name = (grouped_matches) ->
  rtopia         = grouped_matches['rtopia'] || ""
  ptopia         = grouped_matches['liftopia.com'] || ""
  piggy_bank     = grouped_matches['piggy_bank'] || ""
  filtered_array = [rtopia, ptopia, piggy_bank].filter (val) -> val.length
  filtered_array.join '-'

# Internal: Create the hash of Jenkins' deployment parameters
#
# matched_string - the captureg group from Hubot
#
# Returns a hash of parameters
deployment_parameters = (matched_string) ->
  iterator = (memo, str) ->
    tokens = str.split '/'
    if tokens.length > 1
      memo[tokens[0]] = tokens[1]
    else
      memo['host_name'] = tokens[0]
    memo

  cleaned_matches = _.inject matched_string.split(' '), iterator, {}
  host_name       = cleaned_matches['host_name'] || create_host_name cleaned_matches
  parameters      = _.defaults cleaned_matches, defaults

  ptopia     = parameters['liftopia.com']
  rtopia     = parameters['rtopia']
  piggy_bank = parameters['piggy_bank']

  url_params =
    'NODE_NAME': host_name
    'RTOPIA_BRANCH': rtopia
    'PTOPIA_BRANCH': ptopia
    'PIGGY_BANK_BRANCH': piggy_bank

# Internal: Check some things before we fire off a Jenkins' job
#
# params - an object containing the parameters to use
#
# Returns a boolean
validate_hostname = (hostname) ->
  errors = []
  if hostname.length > 30
    errors.push "Host name: #{hostname} is too long."
  errors

# Internal: Acknowledge the command
#
# message - Hubot message
#
# Returns nothing
acknowledge = ->
  "Okie Dokie."

# Internal: Get user's hipchat name from message
#
# message - Hubot message obj
#
# Returns a Hubot user
from_who = (message) ->
  message.message.user

# Add our new functionality to Hubot!
module.exports = (robot) ->
  # Spectators and store initialization
  spect_store  = new Storage robot, 'watchers'
  spectators   = new Spectators spect_store

  # Jenkins, store, and event initialization
  deploy_store = new Storage robot, 'deployments'
  jenkins      = new Jenkins robot

  # Notify spectators of a deployment
  robot.on 'jenkins:deploy', (event) ->
    hostname = event.hostname
    watchers = spectators.watching hostname
    _.each watchers, (user_id) ->
      user          = robot.brain.userForId user_id
      envelope      = {}
      envelope.user = user
      # The reply_to value takes priority and it's usually the room
      delete envelope.user.reply_to
      robot.send envelope, "#{feature_url hostname} has been deployed."

  robot.on 'jenkins:destroy', (event) ->
    hostname = event.hostname
    console.log "#{hostname} was deleted."
    spectators.clear hostname
    deploy_store.remove hostname

  # Listen for Jenkins' to tell us when he has deployment
  robot.router.post '/jenkins/branch_release', (req, res) ->
    jenkins_notification req, res, (data) ->
      hostname = data.build.parameters.NODE_NAME
      robot.emit 'jenkins:deploy', { hostname: hostname }

  # Listen to a notification that a branch was destroyed
  robot.router.post '/jenkins/branch_destroy', (req, res) ->
    jenkins_notification req, res, (data) ->
      hostname = data.build.parameters.NODE_NAME
      robot.emit 'jenkins:destroy', { hostname: hostname }

  # Generate fake staging stuffs
  if process.env.HUBOT_ENABLE_TESTING?
    robot.router.get '/deployments/:env/:name/generate', (req, res) ->
      name = req.params.name
      params =
        'NODE_NAME': name
        'RTOPIA_BRANCH': 'master'
        'PTOPIA_BRANCH': 'master'
        'PIGGY_BANK_BRANCH': 'master'
        deployer:
          id: 123
          jid: '123@chat.what.com'
          name: 'Deploy Bot'
          mention_name: 'deploybot'

      deploy_store.put name, params
      res.send 'OK'

  # Track node details for rundeck and deployment list
  robot.router.post '/deployments/:env/:name/nodes', (req, res) ->
    name = req.params.name
    env  = req.params.env
    data = req.body

    params = deploy_store.get name
    if params?
      for type, hostname of data
        params.nodes[type] = hostname
      deploy_store.put name, params
      res.send 'OK'
    else
      res.status(404).send 'FAIL'

  # Show the nodes in the staging cluster
  robot.router.get '/deployments/:env/:name/nodes', (req, res) ->
    name = req.params.name
    nodes = deploy_store.get(name)['nodes']

    if nodes?
      res.send nodes
    else
      res.status(404).send 'FAIL'

  # Grab the xml version of the entire node list
  robot.router.get '/deployments/:env/nodes.xml', (req, res) ->
    hosts = deploy_store.keys()
    rundeck_xml = [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<!DOCTYPE project PUBLIC "-//DTO Labs Inc.//DTD Resources Document 1.0//EN" "project.dtd">',
      '<project>'
    ]
    if hosts.length > 0
      for i, host of hosts
        params = deploy_store.get(host)
        if params?.nodes?
          for type, hostname of params.nodes
            rundeck_xml.push "  <node name=\"#{host}-#{type}\" description=\"#{host}-#{type}\" tags=\"core,base,staging,#{host},#{type}\" hostname=\"#{hostname}\" osArch=\"x86_64\" osFamily=\"unix\" osName=\"ubuntu\" osVersion=\"14.04\" username=\"rundeck_runner\" environment=\"staging\" roles=\"base,#{type}\" type=\"Node\"/>"
    rundeck_xml.push '</project>'
    res.send(rundeck_xml.join("\n"))

  # Allow users to be notified of specific deployments
  robot.respond /I(?:'m)? watch(?:ing)? (.*)/i, (msg) ->
    whom = from_who msg
    spectators.watch msg.match[1], whom
    msg.send acknowledge()

  # Let users forget about a deployment
  robot.respond /forget (.*)/i, (msg) ->
    whom = from_who msg
    spectators.forget msg.match[1], whom
    msg.send acknowledge()

  # Destroy a feature server
  robot.respond /destroy (.+)/i, (msg) ->
    destroy msg
    robot.emit 'stathat:mark:branchDestroy', msg

  # Deploy using the previous options
  robot.respond /redeploy (.+)/i, (msg) ->
    redeploy msg

  # Deploy our feature server
  robot.respond /deploy ((?!failed$).+)/i, (msg) ->
    deploy msg
    robot.emit 'stathat:mark:branchCreate', msg

  # List all known deployments
  robot.respond /(?:list|get)?\s?deployments/i, (msg) ->
    hosts = deploy_store.keys()
    if hosts.length > 0
      host_list = for i, host of hosts
        params  = deploy_store.get(host)
        details = []
        if params.deployer?.name?
          details.push params.deployer.name
          details.push ' - '
        details.push feature_url host
        if params.nodes?.apps?
          details.push ' - '
          details.push ssh_url params.nodes.apps
        details.push "\n"
        details.push "R / #{params?["RTOPIA_BRANCH"]}"
        details.push ' | '
        details.push "P / #{params?["PTOPIA_BRANCH"]}"
        details.push ' | '
        details.push "PB / #{params?["PIGGY_BANK_BRANCH"]}"
        details.join('')

      msg.send host_list.join("\n")
    else
      msg.send "There aren't any staging clusters right now."

  # Internal: Kick off the deployment job
  #
  # message - Hubot message
  #
  # Returns nothing
  deploy = (message) ->
    params   = deployment_parameters message.match[1]
    hostname = params['NODE_NAME']

    validation_errors = validate_hostname hostname

    if validation_errors.length == 0
      spectators.watch hostname, from_who(message)

      message.send acknowledge()
      params.deployer = from_who(message)
      params.nodes = {}
      deploy_store.put hostname, params

      jenkins.deploy params, generic_callback( ->
        whom = from_who message
      )
    else
      message.send "Deployment aborted due to errors!"
      message.send validation_errors.join "\r\n"

  # Internal: Trigger a Jenkins' redeployment
  #
  # message - the Hubot message object
  #
  # Returns nothing
  redeploy = (message) ->
    hostname = message.match[1]
    params   = deploy_store.get hostname

    if params
      message.send acknowledge()

      spectators.watch hostname, from_who(message)

      jenkins.redeploy params, generic_callback( ->
        whom = from_who message
      )
    else
      message.send "I wasn't able to find a record for #{hostname}"

  # Internal: Request the host be destroyed
  #
  # hostname - which hostname to destroy
  #
  # Returns nothing
  destroy = (message) ->
    hostname = message.match[1]

    jenkins.destroy hostname, generic_callback( ->
      whom = from_who message
      message.send "Destroying staging cluster #{hostname}."
    )

  # Internal: Generic callback for Jenkins' requests
  #
  # success - a more specific success callback
  #
  # Returns a function
  generic_callback = (success) ->
    (err, res, body) ->
      if res.statusCode == 302
        success()
      else
        response = err || body
        console.log "Something unexpected occured: #{response}"

  # Internal: Handle Jenkins notifications
  #
  # req     - Request object
  # res     - Response object
  # success - the callback to be invoked on successful requests
  #
  # Returns nothing
  jenkins_notification = (req, res, success) ->
    res.end('')
    try
      data = req.body
      if data.build.phase == 'FINISHED' and data.build.status == 'SUCCESS'
        success(data)
    catch error
      console.log "jenkins-notify error: #{error}. Data: #{req.body}"
      console.log error.stack
