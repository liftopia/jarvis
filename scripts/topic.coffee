# Description:
#   Topic management for various hubot scripts
#
# Configuration:
#    N/A
#
# Author:
#   amdtech

util = require('util')

module.exports = (robot) ->
  get_topics = ->
    topics = robot.brain.get 'topics'
    topics ?= {}
    topics

  save_topics = (msg, topics) ->
    robot.brain.set 'topics', topics

    new_topic = []
    for own comp, topic of topics[msg.envelope.room]
      new_topic.push topic

    msg.topic(new_topic.join(' | '))

  robot.on 'update-topic', (details) ->
    topics = get_topics()

    msg = details.msg
    room = msg.envelope.room
    component = details.component
    topic = details.topic

    if room? and component?
      topics[room] ?= {}
      topics[room][component] = topic

      save_topics msg, topics

  robot.on 'delete-topic', (details) ->
    topics = get_topics()

    msg = details.msg
    room = msg.envelope.room
    component = details.component

    if room? and component?
      topics[room] ?= {}
      delete topics[room][component]

      save_topics msg, topics
