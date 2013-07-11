# Description:
#   Feature branch deployments
#
# Dependencies:
#   Querystring
#   Underscore
#
# Configuration:
#   HUBOT_JENKINS_URL
#   HUBOT_JENKINS_AUTH
#
# Commands:
#   hubot deploy    <hostname> <repo/branch> <repo/branch>
#   hubot redeploy  <hostname>
#   hubot destroy   <hostname>
#
# Author:
#   doomspork

querystring = require 'querystring'
_           = require 'underscore'

class Jenkins
  # Public: Constructor
  #
  # robot - the Hubot instance
  #
  # Returns a new Jenkins instance
  constructor: (@robot) ->
    @url = process.env.HUBOT_JENKINS_URL
    
  # Public: Redeploy the last request for this hostname
  #
  # hostname - a hostname string
  #
  # Returns false if hostname is unknown
  redeploy: (hostname) ->
    last_request = @get_deploy_request(hostname)
    if last_request
      @deploy(last_request['parameters'], last_request['callback'])
    else
      return false

  # Public: Request a deployment
  #
  # parameters - an hash of key/value pairs to use as GET params
  # callback - a callback method for the HTTP request
  #
  # Returns nothing
  deploy: (parameters, callback) ->
    @store_deploy_request(parameters, callback)
    @run_job 'ReleaseBranch', parameters, callback

  # Public: Destroy the deployment at a particular hostname
  #
  # hostname - a hostname
  # callback - a callback for HTTP requests
  #
  # Returns nothing
  destroy: (hostname, callback) ->
    @run_job 'DestroyBranchHost', {'NodeName': hostname}, callback
    @remove_deploy_request hostname

  # Public: Run a job on Jenkins
  #
  # job - The job name
  # parameters - the GET parameters as key/value pairs
  # callback - a HTTP callback
  #
  # Returns nothing
  run_job: (job, parameters, callback) ->
    safe_params = @safe_url_params parameters
    path = "#{@url}/job/#{job}/buildWithParameters?#{safe_params}"
    console.log("Requesting Jenkins' job at #{path}")
    
    request = @robot.http(path)
    request.header('Content-Length', 0)
    @add_auth_header(request) if process.env.HUBOT_JENKINS_AUTH

    request.post() callback

  # Public: Lists all of the previously requested hosts
  #
  # Returns an array of host strings
  list_hosts: ->
    cache = @deployment_cache
    for host of cache
      host

  deployment_cache: ->
    @robot.brain.get('jenkins-deployments') || {}

  # Internal: Cache this request for destroy/redeploy
  #
  # params - the original parameters used
  # callback - the origin callback used
  #
  # Returns nothing
  store_deploy_request: (params, callback) ->
    hostname = params['HOST_NAME']
    cache = @deployment_cache
    cache[hostname] = { parameters: params, callback: callback }
    @robot.brain.set 'jenkins-deployments', cache
    @robot.brain.save

  # Intenral: Retrieve the parameters and callback for a hostname
  #
  # hostname - a hostname to retrieve
  #
  # Returns the stored values
  get_deploy_request: (hostname) ->
    @deployment_cache[hostname]

  # Internal: Remove cached request
  #
  # hostname - the hostname to remove from cache
  #
  # Returns nothing
  remove_deploy_request: (hostname) ->
    cache = @deployment_cache
    delete cache[hostname]
    @robot.brain.set 'jenkins-deployments', cache
    @robot.brain.save

  # Internal: Generate a transaction key
  #
  # Returns a unique key
  transaction_key: ->
    Date.now()

  # Internal: Add Auth to the headers
  #
  # request - the HTTP request object
  #
  # Returns nothing
  add_auth_header: (request) ->
    auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
    request.headers Authorization: "Basic #{auth}"

  # Internal: Make key/value paramaters URL safe
  #
  # parameters - key/value pairs
  #
  # Returns a URL safe string of parameters
  safe_url_params: (parameters) ->
    querystring.stringify(parameters)

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
  'rtopia':        'master'
  'liftopia.com':  'develop'

# Intenral: Create a unique host name
#
# grouped_matches - Hubot matches as an object
#
# Returns a host name as a String
makeHostName = (grouped_matches) ->
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
  host_name = cleaned_matches['host_name'] || makeHostName(cleaned_matches)
  parameters = _.defaults(cleaned_matches, defaults)

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
verify_hostname = (hostname)->
  errors = []
  if hostname.length > 30
    errors.push("Host name: #{hostname} is too long.")
  errors

acknowledge = (message) ->
  phrase = message.random(confirmative)
  punct = message.random(punctuation)
  message.send "#{phrase}#{punct}"

# Internal: Kick off the deployment job
#
# jenkins - instance of the Jenkins class
# message - Hubot message
#
# Returns nothing
deploy = (jenkins, message) ->
  params = deployment_parameters(message.match[1])
  hostname = params['HOST_NAME']
  validation_errors = verify_hostname hostname

  if validation_errors.length == 0
    jenkins.deploy params, (err, res, body) ->
      if res.statusCode == 302
        branch_url = "http://#{hostname}.liftopia.nu"
        message.send "Your branch should be available at #{branch_url}"
      else
        response = if err then err else body
        message.send "Uh oh, something happened: #{response}"
  else
    message.send "Deployment aborted due to errors!"
    message.send validation_errors.join("\r\n")

# Internal: Request the host be destroyed
#
# jenkins - instance of Jenkins
# hostname - which hostname to destroy
#
# Returns nothing
destroy = (jenkins, hostname, message) ->
  jenkins.destroy hostname, (err, res, body) ->
    if res.statusCode == 302
      acknowledge(message)
    else
      response = err || body
      message.send "Uh oh, something happened: #{response}"

# Add our new functionality to Hubot!
module.exports = (robot) ->
  jenkins = new Jenkins(robot)

  # Returns a snarky remark
  robot.respond /deploy$/i, (msg) ->
    msg.send msg.random ["Wrong!",
      "You're new at this aren't you?",
      "Hahahaha! No.",
      "Successfully declined.",
      "No thanks.",
      "Let me add that to my list of things not to do.",
      "Try again."]

  robot.respond /destroy (.+)/i, (msg) ->
    destroy(jenkins, msg.match[1], msg)

  robot.respond /redeploy (.+)/i, (msg) ->
    acknowledge(msg)
    hostname = msg.match[1]
    success = jenkins.redeploy(hostname)
    if success == false
      msg.send "Unfortunately I have no record of #{hostname} in my brain."

  robot.respond /deploy (.+)/i, (msg) ->
    acknowledge(msg)
    deploy(jenkins, msg)

  robot.respond /list deployments/i, (msg) ->
    hosts = jenkins.list_hosts()
    if hosts.length > 0
      msg.send "These are the ones I'm aware of:"
      host_list = for i, host of hosts
        "#{parseInt(i) + 1}) #{host}"
      msg.send host_list.join("\r\n")
    else
      msg.send "There are none, you should do some work and try again later."
