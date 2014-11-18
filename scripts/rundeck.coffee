# Description:
#   Jenkins Build Manager
#
# Dependencies:
#
# Configuration:
#   RUNDECK_PTOPIA_JID
#   HUBOT_RUNDECK_TOKEN
#   HUBOT_RUNDECK_URL
#
# Commands:
#   N/A
#
# Author:
#   drewzarr

ptopia_job_id = process.env.RUNDECK_PTOPIA_JID
rundeck_url   = process.env.HUBOT_RUNDECK_URL
rundeck_token = process.env.HUBOT_RUNDECK_TOKEN

module.exports = (robot) ->

  robot.on 'rundeck:run', (branch, msg) ->
    data = "argString=-branch #{branch}"
    robot.http("#{rundeck_url}/api/11/job/#{ptopia_job_id}/run")
      .header('X-Rundeck-Auth-Token', rundeck_token)
      .header('Content-Type', 'application/x-www-form-urlencoded')
      .post(data) (err, res, body) ->
        msg.send "Error running job :( #{err}" if err
