# Description:
#   Send messages to all chat rooms.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_HIPCHAT_ANNOUNCE_TOKEN - an admin enabled Hipchat API token
#
# Commands:
#   hubot announce error "<message>"   - Sends an error message to all rooms.
#   hubot announce warning "<message>" - Sends an warning message to all  rooms.
#   hubot announce deploy "<message>"  - Sends an deploy message to all rooms.
#   hubot announce "<message>"         - Sends a message to all rooms.
#
# Author:
#   Sean Callan
#
# URLS:
#   /announce/create - Send a message to designated, comma-separated rooms.
_ = require 'underscore'

module.exports = (robot) ->
  notification_token = process.env.HUBOT_HIPCHAT_ANNOUNCE_TOKEN

  profiles =
    deploy:
      from:    'Deployment'
      color:   'green'
      notify:  1
    error:
      from:    'Error'
      color:   'red'
      notify:  1
    warning:
      from:    'Warning'
      color:   'yellow'
    default:
      from:    'Announcement'
      color:   'purple'

  room_ids = []

  recently_active = (rooms) ->
    day_ago = Math.round((new Date().getTime() - 4320000) / 1000)
    (room.room_id for room in rooms when room.last_active >= day_ago)
  
  announce = (msg, profile, room) ->
    announcement_data = _.extend(profile, {message: msg, room_id: room})
    robot.http('https://api.hipchat.com/v1/rooms/message')
      .query(auth_token: notification_token)
      .query(announcement_data)
      .get() (err, res, body) ->
        if err
          console.log("Announcement error: (#{res.statusCode}) #{err}")

  active_rooms = (callback) ->
    robot.http('https://api.hipchat.com/v1/rooms/list')
      .query(auth_token: notification_token)
      .get() (err, res, body) ->
        json = JSON.parse(body)
        success = false
        if json.rooms
          room_ids = recently_active(json.rooms)
          success = true
        callback(success)

  robot.respond /announce (\w*)?\s?"(.*)"/i, (msg) ->
    active_rooms (success) ->
      if success
        announcement = msg.match[2]
        profile_name = msg.match[1] || 'default'
        profile      = profiles[profile_name]

        for room_id in room_ids
          announce(announcement, profile, room_id)
      else
        msg.send 'Your message did not go out because something done broke.'
