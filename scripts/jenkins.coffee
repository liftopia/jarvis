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
      if err
        msg.send "Error building :( #{err}"
      else
        msg.send "Building #{job} with params #{_.keys params}"
