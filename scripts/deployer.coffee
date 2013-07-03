# Description:
#   Interact with your Jenkins CI server
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JENKINS_URL
#   HUBOT_JENKINS_AUTH
#
# Commands:
#   hubot deploy <repo/branch> <repo/branch>
#
# Author:
#   doomspork

querystring = require 'querystring'
_           = require 'underscore'

# Internal: Contains the Jenkin's job name
job = 'ReleaseBranch'

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
  console.log(rtopia)
  console.log(ptopia)
  filtered_array = [rtopia, ptopia].filter (val) -> val.length
  console.log(filtered_array)
  filtered_array.join('-')

# Internal: build the query string for the Jenkin's job
#
# matched_string - the captureg group from Hubot
#
# Returns a hash of parameters
jenkinsParameters = (matched_string) ->
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
verifyParameters = (params) ->
  errors = []
  if params['HOST_NAME'].length > 30
    errors.push("Host name: #{params['HOST_NAME']} is too long, please provide an override.")
  errors

# Internal: Trigger a build
#
# msg - a Hubot message object
#
# Returns nothing
jenkinsBuild = (msg) ->
  mention = "#{msg.message.user.mention_name}"

  url = process.env.HUBOT_JENKINS_URL
   
  params = jenkinsParameters(msg.match[1])
  validation_errors = verifyParameters(params)

  if validation_errors.length == 0
    msg.send "#{msg.random(confirmative)}#{msg.random(punctuation)}"

    safe_params = querystring.stringify(params)
    path = "#{url}/job/#{job}/buildWithParameters?#{safe_params}"
    
    console.log("Requesting Jenkins' job at #{path}")
    
    req = msg.http(path)
    
    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"
    
    req.header('Content-Length', 0)
    req.post() (err, res, body) ->
      if err
        msg.send "Jenkins says: #{err}"
      else if res.statusCode == 302
        hyperlink = "http://#{params['HOST_NAME']}.liftopia.nu"
        msg.reply "Your deployment will be available here shortly: #{hyperlink}"
      else
        msg.send "Jenkins says: #{body}"
  else
    msg.send "Errors detected, deployment aborted!"
    msg.send validation_errors.join("\r\n")

module.exports = (robot) ->
  robot.respond /deploy$/i, (msg) ->
    msg.send msg.random ["Wrong!", "You're new at this aren't you?", "Hah, no.", "Successfully declined."]
  robot.respond /deploy (.+)/i, (msg) ->
    jenkinsBuild(msg)

  robot.jenkins = {
    build: jenkinsBuild
  }
