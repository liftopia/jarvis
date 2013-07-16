# Description:
#   Feature beta releases
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
#   hubot release beta
#
# Author:
#   gabriel

querystring = require 'querystring'
_           = require 'underscore'

class Releaser
  # Public: Constructor
  #
  # robot - the Hubot instance
  #
  # Returns a new Releaser instance
  constructor: (@robot) ->
    @url = process.env.HUBOT_JENKINS_URL

  # Public: Request a deployment
  #
  # parameters - an hash of key/value pairs to use as GET params
  # callback - a callback method for the HTTP request
  #
  # Returns nothing
  deploy: (callback) ->
    @run_job 'ReleaseBeta', callback

  # Public: Run a job on Jenkins
  #
  # job - The job name
  # parameters - the GET parameters as key/value pairs
  # callback - a HTTP callback
  #
  # Returns nothing
  run_job: (job, callback) ->
    path = "#{@url}/job/#{job}/buildWithParameters"
    console.log("Requesting Jenkins' job at #{path}")
    
    request = @robot.http(path)
    request.header('Content-Length', 0)
    @add_auth_header(request) if process.env.HUBOT_JENKINS_AUTH

    request.post() callback

  # Internal: Add Auth to the headers
  #
  # request - the HTTP request object
  #
  # Returns nothing
  add_auth_header: (request) ->
    auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
    request.headers Authorization: "Basic #{auth}"

# Internal: A list of responses for Hubot to use
confirmative = ["Si c'est ce que vous voulez",
  "Je m'y mets tout de suite",
  "J'ai compris",
  "5/5",
  "Biensure",
  "Entendu!",
  "Tout ce que vous voulez",
  "Avec plaisir",
  "Ca marche!",
  "Je peux arranger ça"]

punctuation  = ['.', '!', '...']

capitalize = (string) ->
  return string.charAt(0).toUpperCase() + string.slice(1);

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
deploy = (release, message) ->
  if message.match[1] == 'beta'
    release.deploy (err, res, body) ->
      if res.statusCode == 302
        branch_url = "http://www.liftopia.tv"
        message.send "#{capitalize(message.match[1])} should be release and available at #{branch_url}"
      else
        response = if err then err else body
        message.send "Uh oh, something happened: #{response}"
  else
    message.send "Deployment aborted due to errors!"
    message.send validation_errors.join("\r\n")

# Add our new functionality to Hubot!
module.exports = (robot) ->
  release = new Releaser(robot)

  robot.respond /release (.*)/i, (msg) ->
    console.log(msg)
    acknowledge(msg)
    deploy(release, msg)
