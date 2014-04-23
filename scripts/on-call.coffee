# Description:
#   Save the current on call people
#
# Commands:
#   hubot on call                     - Get the full on call list
#   hubot on call for <team>          - Get the on call person for <team>
#   hubot on call for <team> <person> - Set the on call <person> for <team>
#   hubot remove on call for <team>   - Remove the on call person from <team>
#
# Examples:
#   hubot on call
#   hubot on call for product
#   hubot on call for dev sean
#   hubot on call for dev aaron daniel
#   hubot remove on call for product
#
# Author:
#   amdtech

_ = require 'underscore'

module.exports = (robot) ->
  ON_CALL_KEY = 'on_call'

  # more things that need to be librarified... this came from roles.coffee
  getAmbiguousUserText = (users) ->
    "Be more specific, I know #{users.length} people named like that: #{(user.name for user in users).join(", ")}"

  robot.respond /on call for (\w+) @?([\w .\-]+)$/i, (msg) ->
    team = msg.match[1]
    name = msg.match[2].trim()

    users = robot.brain.usersForFuzzyName(name)
    if users.length is 1
      user = users[0]
      if user.phone
        on_call = robot.brain.get ON_CALL_KEY
        on_call ?= {}
        on_call[team] = user.id
        robot.brain.set ON_CALL_KEY, on_call
        msg.send "#{name} is on call with #{user.phone.replace(/(\d{3})(\d{3})(\d{4})/, '$1.$2.$3')} as their phone number"
      else
        msg.send "#{name} doesn't have a phone listed :( use `#{robot.name} #{name} has phone number <phone number>` to add one!"
    else if users.length > 1
      msg.send getAmbiguousUserText users
    else
      msg.send "#{name}? Never heard of 'em"

  robot.respond /on call$/i, (msg) ->
    on_call = robot.brain.get ON_CALL_KEY
    response = []
    if on_call and not _.isEmpty(on_call)
      for own team, user_id of on_call
        user = robot.brain.userForId(user_id)
        response.push "#{team}: #{user.name} - #{user.phone.replace(/(\d{3})(\d{3})(\d{4})/, '$1.$2.$3')}"
      msg.send response.join("\n")
    else
      msg.send "Uh oh! Nobody's on call!"

  robot.respond /remove on call for (\w+)$/i, (msg) ->
    team = msg.match[1]
    on_call = robot.brain.get ON_CALL_KEY
    delete on_call[team]
    robot.brain.set ON_CALL_KEY, on_call

    msg.send "Removed on call for #{team}"

  robot.respond /on call for (\w+)$/i, (msg) ->
    team = msg.match[1]
    on_call = robot.brain.get ON_CALL_KEY
    if on_call and on_call[team]
      user = robot.brain.userForId(on_call[team])
      msg.send "#{user.name} is on call at #{user.phone.replace(/(\d{3})(\d{3})(\d{4})/, '$1.$2.$3')}"
    else
      msg.send "Nobody is on call for #{team}"
