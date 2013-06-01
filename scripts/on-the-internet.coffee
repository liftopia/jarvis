# Description:
#   Responds with the proper Liftopia valediction
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   (latah|c ya|adios|peace out) - Get the valediction
#
# Author:
#   jcarouth

module.exports = (robot) ->
  robot.hear /lat(ah?|er)|adios|peace out|c ?ya|see ya/i, (msg) ->
    msg.send "See you on the Internet."
