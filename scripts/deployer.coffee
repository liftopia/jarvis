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
confirmative = ["If that's what you want", "I'm on it", "You've got it", "Affirmative", "Roger that", "10-4", "Copy that", "Anything for you", "With great pleasure", "Yeah", "Sure, that can be arranged"]
punctuation  = ['.', '!', '...']

# Internal: Branch defaults for rtopia and liftopia.com
defaults =
  'rtopia':        'master'
  'liftopia.com':  'develop'

# Intenral: Create a unique host name
#
# rtopia_branch - the branch name as a String
# ptopia_branch - the branch name as a String
#
# Returns a host name as a String
makeHostName = (rtopia_branch, ptopia_branch) ->
  "#{rtopia_branch}-#{ptopia_branch}"

# Internal: build the query string for the Jenkin's job
#
# branches - an object similar to `defaults` above
#
# Returns a hash of parameters 
jenkinsParameters = (branches) ->
  rtopia_branch = branches['rtopia']
  ptopia_branch = branches['liftopia.com']

  params =
    'HOST_NAME': makeHostName(rtopia_branch, ptopia_branch)
    'RTOPIA_BRANCH': rtopia_branch
    'PTOPIA_BRANCH': ptopia_branch

# Internal: Trigger a build
#
# msg - a Hubot message object
#
# Returns nothing
jenkinsBuild = (msg) ->
    mention = "@#{msg.message.user.mention_name}"
    msg.send "#{msg.random(confirmative)}#{msg.random(punctuation)}"

    url = process.env.HUBOT_JENKINS_URL
   
    iterator = (memo, str) ->
       tokens = str.split('/')
       memo[tokens[0]] = tokens[1] if tokens.length > 1
       memo

    repo_branches = _.defaults(_.inject(msg.match[1].split(' '), iterator, {}), defaults)
    params = jenkinsParameters(repo_branches)
    path = "#{url}/job/#{job}/buildWithParameters?#{querystring.stringify(params)}"

    req = msg.http(path)

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"

    req.header('Content-Length', 0)
    req.post() (err, res, body) ->
        if err
          msg.send "Jenkins says: #{err}"
        else if res.statusCode == 302
          msg.send "#{mention}, your deployment will be available shortly at this hyperlink: http://#{params['HOST_NAME']}.liftopia.nu"
        else
          msg.send "Jenkins says: #{body}"

module.exports = (robot) ->
  robot.respond /deploy (.+)?/i, (msg) ->
    jenkinsBuild(msg)

  robot.jenkins = {
    build: jenkinsBuild
  }
