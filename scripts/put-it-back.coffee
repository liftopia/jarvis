# Description:
#   put back the table
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#
# Author:
#   ajacksified

module.exports = (robot) ->
  robot.hear /（╯°□°）╯︵ ┻━┻|\((tableflip)\)/i, (msg) ->
    msg.send('┬──┬ ノ( ゜-゜ノ)')
