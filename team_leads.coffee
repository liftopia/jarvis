# Description:
#   Set the CS team leads and update room topic
#
# Commands:
#   hubot today's team leads are <name, name> - Set the leads and room topic
#   hubot who are today's leads?              - Get the leads for the day
#
# Examples:
#   hubot today's team leads are Steve, Jackie, Mike
#   hubot who are today's lead?
#
# Author:
#   doomspork

# _ = require 'underscore'

# module.exports = (robot) ->
# CS_LEADS_KEY = 'cs_team'

# robot.respond /today's (?:team\s?)?leads are (\w+(?:,\s?\w+)?)/i, (msg) ->