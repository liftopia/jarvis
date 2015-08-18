# Description:
#   Jenkins Build Manager
#
# Dependencies:
#   jenkins
#
# Configuration:
#   HUBOT_JENKINS_TOKEN
#   HUBOT_JENKINS_URL
#
# Commands:
#   N/A
#
# Author:
#   amdtech

jenkins = require('jenkins')(process.env.HUBOT_JENKINSIO_URL)

module.exports = (robot) ->
  token = process.env.HUBOT_JENKINS_TOKEN

  robot.on 'jenkinsio:build', (job, params, msg) ->
    jenkins.job.build job, { token: token, parameters: params }, (err) ->
      # to get around a jenkins bug in the version we're running
      if err?.res?.statusCode != 302
        callback?(err)
      else
        callback?()
