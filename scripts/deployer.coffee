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
#   hubot jenkins build <job> - builds the specified Jenkins job
#   hubot jenkins build <job>, <params> - builds the specified Jenkins job with parameters as key=value&key2=value2
#   hubot jenkins list <filter> - lists Jenkins jobs
#   hubot jenkins describe <job> - Describes the specified Jenkins job

#
# Author:
#   dougcole
#   doomspork

querystring = require 'querystring'

job = 'ReleaseBranch'

defaults =
  'rtopia':        'master'
  'liftopia.com':  'develop'

jenkinsBuild = (msg) ->
    url = process.env.HUBOT_JENKINS_URL
    
    repo_options = _.inject(_.rest(msg.match, 2), ((memo, matched_string) ->
       tokens = matched_string.split('/')
       memo[tokens[0]] = tokens[1] if tokens.length > 1
       memo), {})

    params = querystring.stringify(repo_options)  

    path = if params then "#{url}/job/#{job}/buildWithParameters?#{params}" else "#{url}/job/#{job}/build"

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
  robot.respond /deploy(?: (.+)){0,2}/i, (msg) ->
    jenkinsBuild(msg)

  robot.jenkins = {
    build: jenkinsBuild
  }
