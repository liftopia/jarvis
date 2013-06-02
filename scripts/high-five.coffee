# Description:
#   Jarvis High Five
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   jarvis (high ?five|\^5) - get a HipChat high five
#   jarvis high five <user> - Have jarvis high five <user>
#
# Author:
#   jcarouth

module.exports = (robot) ->
  robot.respond /(?:high ?five|\^5)(?: (@?[\w .\-_]+))?/i, (msg) ->
    if (msg.match[1]) 
      user = msg.match[1].trim()
      msg.send "#{user} (highfive)"
    else
      msg.send "(highfive)"
