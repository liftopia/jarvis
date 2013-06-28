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

job = 'ReleaseBranch'

defaults =
  'rtopia':        'master'
  'liftopia.com':  'develop'

jenkinsBuild = (msg) ->
    url = process.env.HUBOT_JENKINS_URL
   
    iterator = (memo, str) ->
       tokens = str.split('/')
       memo[tokens[0]] = tokens[1] if tokens.length > 1
       memo

    repo_branches = _.defaults(_.inject(msg.match[1].split(' '), iterator, {}), defaults)
    params = querystring.stringify(repo_branches)
    path = if params then "#{url}/job/#{job}/buildWithParameters?#{params}" else "#{url}/job/#{job}/build"

    console.log("Jenkins job path: #{path}")

    req = msg.http(path)

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"

    req.header('Content-Length', 0)
    req.post() (err, res, body) ->
        if err
          msg.send "Jenkins says: #{err}"
        else if res.statusCode == 302
          msg.send "Build started for #{job} #{res.headers.location}"
        else
          msg.send "Jenkins says: #{body}"

module.exports = (robot) ->
  robot.respond /deploy (.+)?/i, (msg) ->
    jenkinsBuild(msg)

  robot.jenkins = {
    build: jenkinsBuild
  }
