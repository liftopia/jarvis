# Description:
#   Stathat stat poster
#
# Dependencies:
#   
#
# Configuration:
#   HUBOT_STATHAT_KEY
#
# Commands:
#   N/A
#
# Author:
#   drewzarr

stathat_key = process.env.HUBOT_STATHAT_KEY

module.exports = (robot) ->
  # Mark failed deploys
  robot.on 'stathat:mark:deployFailed', (manifest, msg) ->
    repo = repo
    data = JSON.stringify({
      "ezkey": "#{stathat_key}"
      "data": [
        {"stat" : "#{manifest.repo} failed deploys", "count" : 1},
        {"stat" : "#{manifest.repo} deploys", "count" : -1}
      ]
      })

    robot.http("http://api.stathat.com/ez")
      .header('Content-Type', 'application/json')
      .post(data) (err, res, body) ->
        msg.send "Error running job :( #{err}" if err

  # Mark Branch Creation
  robot.on 'stathat:mark:branchCreate', (msg) ->
    data = "stat=Branch Created&email=#{stathat_key}&count=1"

    robot.http("http://api.stathat.com/ez")
      .header('Content-Type', 'application/x-www-form-urlencoded')
      .post(data) (err, res, body) ->
        msg.send "Error running job :( #{err}" if err

  # Mark branch destorys
  robot.on 'stathat:mark:branchDestroy', (msg) ->
    data = "stat=Branch Destroyed&email=#{stathat_key}&count=1"

    robot.http("http://api.stathat.com/ez")
      .header('Content-Type', 'application/x-www-form-urlencoded')
      .post(data) (err, res, body) ->
        msg.send "Error running job :( #{err}" if err
