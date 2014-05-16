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

  format_phone = (phone) ->
    phone.replace(/(\d{3})(\d{3})(\d{4})/, '$1.$2.$3')

  # more things that need to be librarified... this came from roles.coffee
  getAmbiguousUserText = (users) ->
    "Be more specific, I know #{users.length} people named like that: #{(user.name for user in users).join(", ")}"

  capitalize = (string) ->
    string[0].toUpperCase() + string[1..-1].toLowerCase()

  update_topic = (msg) ->
    on_call = robot.brain.get ON_CALL_KEY
    topic = []

    if on_call? and not _.isEmpty(on_call)
      for own team, user_id of on_call
        user = robot.brain.userForId user_id
        topic.push "#{capitalize team}: #{user.name} - #{format_phone user.phone}"

    if _.isEmpty(topic)
      robot.emit 'delete-topic', { msg: msg, component: 'on-call' }
    else
      robot.emit 'update-topic', { msg: msg, topic: topic.join(' / '), component: 'on-call' }

  robot.respond /on call for (\w+) @?([\w .\-]+)$/i, (msg) ->
    team = msg.match[1].toLowerCase()
    name = msg.match[2].trim()

    users = robot.brain.usersForFuzzyName(name)
    if users.length is 1
      user = users[0]
      if user.phone
        on_call = robot.brain.get ON_CALL_KEY
        on_call ?= {}
        on_call[team] = user.id
        robot.brain.set ON_CALL_KEY, on_call

        update_topic msg

        msg.send "#{name} is on call with #{format_phone user.phone} as their phone number"
      else
        msg.send "No number for #{name} :( use `#{robot.name} #{name} has phone number <phone number>` to add one!"
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
        response.push "#{capitalize team}: #{user.name} - #{format_phone user.phone}"

      msg.send response.join("\n")
    else
      msg.send "Uh oh! Nobody's on call!"

  robot.respond /remove on call for (\w+)$/i, (msg) ->
    team = msg.match[1].toLowerCase()
    on_call = robot.brain.get ON_CALL_KEY
    delete on_call[team]
    robot.brain.set ON_CALL_KEY, on_call

    update_topic msg

    msg.send "Removed on call for #{team}"

  robot.respond /on call for (\w+)$/i, (msg) ->
    team = msg.match[1].toLowerCase()
    on_call = robot.brain.get ON_CALL_KEY
    if on_call and on_call[team]
      user = robot.brain.userForId(on_call[team])
      msg.send "#{user.name} is on call at #{format_phone user.phone}"
    else
      msg.send "Nobody is on call for #{team}"

  # This is borrowed from 46elks.coffee, for proper topic handling
  robot.respond /@?([\w .-_]+) has phone number (\d*)*$/i, (msg) ->
    name  = msg.match[1]
    phone = msg.match[2].trim()

    users = robot.brain.usersForFuzzyName(name)
    if users.length is 1
      user = users[0]
      if user.phone == phone
        msg.send "I know."
      else
        user.phone = phone
        update_topic msg
        msg.send "Ok, #{name} has phone #{format_phone phone}."
    else if users.length > 1
      msg.send getAmbiguousUserText users
    else
      msg.send "I don't know anything about #{name}."

  # This is borrowed from 46elks.coffee, for proper topic handling
  robot.respond /@?give me the phone number to ([\w .-_]+)*/i, (msg) ->
    name  = msg.match[1]
    users = robot.brain.usersForFuzzyName(name)
    if users.length is 1
      user = users[0]
      if user.phone.length < 1
        msg.send "#{user.name} has no phone, set it first!"
      else
        msg.send "#{user.name} has phone number #{format_phone user.phone}."
    else if users.length > 1
      msg.send getAmbiguousUserText users
    else
      msg.send "I don't know anything about #{name}."
