# Description:
#   Jenkins Build Manager
#
# Dependencies:
#   jenkins
#   underscore
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

_       = require 'underscore'
jenkins = require('jenkins')(process.env.HUBOT_JENKINS_URL)

module.exports = (robot) ->
  token = process.env.HUBOT_JENKINS_TOKEN

  robot.on 'jenkins:build', (job, params, msg) ->
    jenkins.job.build job, { token: token, parameters: params }, (err) ->
      msg.send "Error building :( #{err}" if err
