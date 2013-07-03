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
makeUniqueHostName = (rtopia_branch, ptopia_branch) ->
  "#{rtopia_branch}-#{ptopia_branch}-#{Date.now()}"

# Internal: build the query string for the Jenkin's job
#
# branches - an object similar to `defaults` above
#
# Returns a URL safe string
jenkinsParameters = (branches) ->
  rtopia_branch = branches['rtopia']
  ptopia_branch = branches['liftopia.com']

  params =
    'host_name': makeUniqueHostName(rtopia_branch, ptopia_branch)
    'rtopia_branch': rtopia_branch
    'ptopia_branch': ptopia_branch

  querystring.stringify(params)

# Internal: Trigger a build
#
# msg - a Hubot message object
#
# Returns nothing
jenkinsBuild = (msg) ->
    mention = "@#{msg.message.user.mention_name}"
    msg.send "You've got it #{mention}!"
    url = process.env.HUBOT_JENKINS_URL
   
    iterator = (memo, str) ->
       tokens = str.split('/')
       memo[tokens[0]] = tokens[1] if tokens.length > 1
       memo

    repo_branches = _.defaults(_.inject(msg.match[1].split(' '), iterator, {}), defaults)
    params = jenkinsParameters(repo_branches)
    path = "#{url}/job/#{job}/buildWithParameters?#{params}"
    
    console.log(path)

    req = msg.http(path)

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"

    req.header('Content-Length', 0)
    req.post() (err, res, body) ->
        if err
          msg.send "Jenkins says: #{err}"
        else if res.statusCode == 302
          msg.send "#{mention} your deployment should be here shortly: http://#{params['host_name']}.liftopia.nu"
        else
          msg.send "Jenkins says: #{body}"

module.exports = (robot) ->
  robot.respond /deploy (.+)?/i, (msg) ->
    jenkinsBuild(msg)

  robot.jenkins = {
    build: jenkinsBuild
  }
