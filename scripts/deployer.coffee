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
#   hubot fuhgeddaboud <hostname> - Ya ain't tryin' ta hear about it no mo
#   hubot deploy <hostname> <repo/branch> <repo/branch> - Deploy a custom branch server
#   hubot redeploy <hostname> - Re-trigger the last known deployment for this host
#   hubot destroy <hostname> - Destroy the server
#
# Author:
#   doomspork

querystring = require 'querystring'
_           = require 'underscore'
http        = require 'scoped-http-client'

BRANCH_DOMAIN = 'liftopia.nu'

# Internal: Get the url for a hostname
#
# hostname - the feature server's hostname
#
# Returns a string
feature_url = (hostname) ->
  "http://#{hostname}.#{BRANCH_DOMAIN}"

# Internal: MUHAHAHA!  Helper method for tracking actions in Orwell
#
# action  - the action that occurred
# user    - the user's name
# details - any additional data
#
# Returns nothing
orwell_track = (action, user, details) ->
  data =
    token:        'ge0XVpMpqwZWg2UjwNCaweisJhjuu6Xgzi93PnKO'
    channel:      'jarvis'
    action:       action
    distinct_id:  user
    details:      details

  post_data = querystring.stringify(data)

  http.create('http://api.orwell.io')
    .path('v1/track')
    .post(post_data) (err, resp, body) ->
      if resp.statusCode == 200
        console.log('Successfully tracked action with Orwell')
      else
        console.log("Error communicating with Orwell: #{body}")

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
    watchers = @watching(hostname)
    if watchers.indexOf(user) == -1
      watchers.push(user)
      @store.put(hostname, watchers)

  # Public: Remove a user from the list of spectators for a hostname
  #
  # hostname - the hostname to forget
  # user - the user chat name
  #
  # Returns nothing
  forget: (hostname, user) ->
    watchers = @watching(hostname)
    index = watchers.indexOf(user)
    if index >= 0
      delete watchers[user_id]
      @store.put(hostname, watchers)

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
    @robot.emit 'jenkins:deploy', { hostname: parameters['HOST_NAME'] }
    @run_job 'ReleaseBranch', parameters, callback

  # Public: Destroy the deployment at a particular hostname
  #
  # hostname - a hostname
  # callback - a callback for HTTP requests
  #
  # Returns nothing
  destroy: (hostname, callback) ->
    @robot.emit 'jenkins:destroy', { hostname: hostname }
    @run_job 'DestroyBranchHost', {'NodeName': hostname}, callback

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
      .path("job/#{job}/buildWithParameters?#{safe_params}")
      .header('Content-Length', 0)

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      request.header('Authorization', "Basic #{auth}")
    
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

# Internal: A list of responses for Hubot to use
confirmative = ["If that's what you want",
  "I'm on it",
  "You've got it",
  "Affirmative",
  "Roger that",
  "10-4",
  "Copy that",
  "Anything for you",
  "With great pleasure",
  "Yeah",
  "Sure, that can be arranged"]

punctuation  = ['.', '!', '...']

# Internal: Branch defaults for rtopia and liftopia.com
defaults =
  'rtopia':        'develop'
  'liftopia.com':  'develop'

# Intenral: Create a unique host name
#
# grouped_matches - Hubot matches as an object
#
# Returns a host name as a String
create_host_name = (grouped_matches) ->
  rtopia = grouped_matches['rtopia'] || ""
  ptopia = grouped_matches['liftopia.com'] || ""
  filtered_array = [rtopia, ptopia].filter (val) -> val.length
  filtered_array.join('-')

# Internal: Create the hash of Jenkins' deployment parameters
#
# matched_string - the captureg group from Hubot
#
# Returns a hash of parameters
deployment_parameters = (matched_string) ->
  iterator = (memo, str) ->
    tokens = str.split('/')
    if tokens.length > 1
      memo[tokens[0]] = tokens[1]
    else
      memo['host_name'] = tokens[0]
    memo

  cleaned_matches = _.inject(matched_string.split(' '), iterator, {})
  host_name = cleaned_matches['host_name'] || create_host_name cleaned_matches
  parameters = _.defaults cleaned_matches, defaults

  ptopia = parameters['liftopia.com']
  rtopia = parameters['rtopia']

  url_params =
    'HOST_NAME': host_name
    'RTOPIA_BRANCH': rtopia
    'PTOPIA_BRANCH': ptopia

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

# Internal: Acknowledge the command with a random phrase
#
# message - Hubot message
#
# Returns nothing
acknowledge = ->
  phrase    = random confirmative
  punct     = random punctuation
  "#{phrase}#{punct}"

# Internal: Get a random array element
#
# arr - an array
#
# Return a value
random = (arr) ->
  arr[Math.floor(Math.random()*arr.length)]

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
  spect_store  = new Storage(robot, 'watchers')
  spectators   = new Spectators(spect_store)

  # Jenkins, store, and event initialization
  deploy_store = new Storage(robot, 'deployments')
  jenkins      = new Jenkins(robot)

  # Notify spectators of a deployment
  robot.on 'jenkins:deploy', (event) ->
    hostname = event.hostname
    watchers = spectators.watching hostname
    mentions = _.map watchers, (user) -> "@#{user}"

    robot.messageRoom 'Development', "#{mentions.join(', ')} #{hostname} was deployed."

  robot.on 'jenkins:destroy', (event) ->
    hostname = event.hostname
    console.log "#{hostname} was deleted."
    spectators.clear hostname

  # Listen for Jenkins' to tell us when he has deployment
  robot.router.get '/jenkins/deployed/:hostname', (req, res) ->
    host = req.params.hostname
   
  # Allow users to be notified of specific deployments
  robot.respond /I(?:'m)? watch(?:ing)? (.*)/i, (msg) ->
    whom = from_who msg
    spectators.watch msg.match[1], whom.mention_name
    msg.send acknowledge()

  # Let users forget about a deployment
  robot.respond /(fuhgeddaboud|forget) (.*)/i, (msg) ->
    whom = from_who msg
    spectators.forget msg.match[1], whom.mention_name
    msg.send acknowledge()

  # Returns a snarky remark
  robot.respond /deploy$/i, (msg) ->
    msg.send msg.random ["Wrong!",
      "You're new at this aren't you?",
      "Hahahaha! No.",
      "Successfully declined.",
      "No thanks.",
      "Let me add that to my list of things not to do.",
      "Try again."]

  # Destroy a feature server
  robot.respond /destroy (.+)/i, (msg) ->
    destroy msg

  # Deploy using the previous options
  robot.respond /redeploy (.+)/i, (msg) ->
    redeploy msg

  # Deploy our feature server
  robot.respond /deploy (.+)/i, (msg) ->
    deploy msg

  # List all known deployments
  robot.respond /(?:list|get)?\s?deployments/i, (msg) ->
    hosts = deploy_store.keys()
    if hosts.length > 0
      host_list = for i, host of hosts
        "#{parseInt(i) + 1}) #{host}"
      host_string = host_list.join("\r\n")
      msg.send "These are the ones I'm aware of:\n#{host_string}"
    else
      response = random(["There are none, you might want to fix that.",
        "Empty.",
        "(crickets)",
        "You've got to deploy something first.",
        "There aren't any, get to work!"])
      msg.send response
     
  # Internal: Kick off the deployment job
  #
  # message - Hubot message
  #
  # Returns nothing
  deploy = (message) ->
    params   = deployment_parameters message.match[1]
    hostname = params['HOST_NAME']
  
    validation_errors = validate_hostname hostname
  
    if validation_errors.length == 0
      message.send acknowledge()
      deploy_store.put hostname, params

      jenkins.deploy params, generic_callback( ->
        whom = from_who message
        orwell_track('deploy', whom.name, {hostname: hostname})
        url = feature_url hostname
        message.send "@#{whom.mention_name}, your branch is at #{url}"
      )
    else
      message.send "Deployment aborted due to errors!"
      message.send validation_errors.join("\r\n")
  
  # Internal: Trigger a Jenkins' redeployment
  #
  # message - the Hubot message object
  #
  # Returns nothing
  redeploy = (message) ->
    hostname = message.match[1]

    params = deploy_store.get hostname

    if params
      message.send acknowledge()

      jenkins.deploy params, generic_callback( ->
        whom = from_who message
        orwell_track 'redeploy', whom.name, {hostname: hostname}
        message.send "@#{whom.mention_name}, I'm redeploying to #{feature_url(hostname)}"
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
    deploy_store.remove hostname
    remarks = ["Let's watch the world burn!",
      "Target eliminated.",
      "Extinguished.",
      "You're sick!  What if he had a family...",
      "This is the best part of my job!",
      "click. click. (boom)"]
  
    jenkins.destroy hostname, generic_callback( ->
      whom = from_who message
      orwell_track 'destroy', whom.name, {hostname: hostname}
      message.send random(remarks)
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
