# Description:
#   Rundeck Job Runner
#
# Dependencies:
#   underscore
#
# Configuration:
#   HUBOT_RUNDECK_JIDS
#   HUBOT_RUNDECK_TOKEN
#   HUBOT_RUNDECK_URL
#
# Commands:
#   N/A
#
# Author:
#   drewzarr
_             = require('underscore')
rundeck_url   = process.env.HUBOT_RUNDECK_URL
rundeck_token = process.env.HUBOT_RUNDECK_TOKEN

module.exports = (robot) ->
  robot.on 'rundeck:run', (manifest, msg) ->
    job_id = {}
    _.each process.env.HUBOT_RUNDECK_JIDS.split(','), (job) ->
      [ job, jid ] = job.split(':')
      job_id[job] = jid

    data = "argString=-branch #{manifest.branch}"
    robot.http("#{rundeck_url}/api/11/job/#{job_id[manifest.repo]}/run")
      .header('X-Rundeck-Auth-Token', rundeck_token)
      .header('Content-Type', 'application/x-www-form-urlencoded')
      .post(data) (err, res, body) ->
        msg.send "Error running job :( #{err}" if err
