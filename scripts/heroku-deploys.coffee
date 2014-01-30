# Description:
#   Assign display names for Heroku apps and users
#
# Configuration:
#   HEROKU_DEPLOY_ROOMS
#
# Commands:
#   hubot heroku knows app <display name> as <name>      - assign a display name to a Heroku app
#   hubot heroku knows user <display name> as <name>      - assign a display name to a Heroku app
#
# Examples:
#   hubot heroku knows app Jarvïs Bötman as lift-jarvis
#   hubot heroku knows user TestUser as user@test.com 
#
# Author:
#   doomspork

class KeyValueStore
  constructor: (@namespace, @robot) ->
    @cache = {}
    @robot.brain.on 'loaded', =>
      @cache = @robot.brain.get(@namespace) || @cache

  save = ->
    @robot.brain.set(@namespace, @cache)

  add: (key, value) ->
    @cache[key] = value
    save.call @

  remove: (key) ->
    delete @cache[key]
    save.call @

  get: (key) ->
    @cache[key]

  clear: ->
    @cache = []
    save.call @

rooms = (process.env.HEROKU_DEPLOY_ROOMS || '').split(',')

module.exports = (robot) ->
  app_store  = new KeyValueStore('heroku_apps', robot)
  user_store = new KeyValueStore('heroku_users', robot)

  robot.respond /heroku knows (app|user) (.*) as (.+)/i, (msg) ->
    collection = if (msg.match[1] == 'app') then app_store else user_store
    collection.add msg.match[3], msg.match[2]
    msg.send msg.random ['You got it', '(thumbsup)', 'Sure', 'Always excited to help out', 'Roger that']

  robot.router.post '/heroku/deploy', (req, res) ->
    res.send('')
    heroku_app  = req.body.app
    heroku_user = req.body.user
    app         = app_store.get(heroku_app)   || heroku_app
    user        = user_store.get(heroku_user) || heroku_user
    event       =
      message: "#{app} was leveled up by #{user}!"
      profile: 'deploy'

    rooms.forEach (room) ->
      event['room'] = room
      robot.emit 'room_announce', event
