# Description:
#   Manage the users in the brain easily
#
# Commands:
#   hubot update user <id> <field> <value> - Update a particular field in the brain
#   hubot delete user <id> - Remove a user from the brain.
#   hubot delete user <id> <field> - Remove a specific field from a user.
#
# Configuration:
#   MANAGE_USER_ADMINS
#
# Author:
#   amdtech

is_allowed = (message, id, del = false) ->
  admins = (process.env.MANAGE_USER_ADMINS || '').split(',')

  if del and id in admins
    message.send "Trying to delete an admin isn't very nice."
    false
  else if message.message.user.id in admins
    true
  else
    message.send "Not allowed!"
    false

module.exports = (robot) ->
  robot.respond /delete user (\d+)$/i, (msg) ->
    id = msg.match[1]

    if is_allowed msg, id, true
      delete robot.brain.data['users'][id]
      msg.send "Deleted #{id}"

  robot.respond /delete user (\d+) (\w+)$/i, (msg) ->
    id = msg.match[1]
    field = msg.match[2]

    if is_allowed msg, id
      if field in [ 'id', 'jid', 'name' ]
        msg.send "Don't even try to delete #{field}"
      else
        delete robot.brain.data['users'][id][field]
        msg.send "Deleted #{id}'s #{field}"

  robot.respond /update user (\d+) (\w+) (.*)$/i, (msg) ->
    id = msg.match[1]
    field = msg.match[2]
    value = msg.match[3]

    if is_allowed msg, id
      if field in [ 'id', 'name' ]
        msg.send "Don't even try to update #{field}"
      else
        robot.brain.data['users'][id][field] = value
        msg.send "Updated #{id}'s #{field} to #{value}"
