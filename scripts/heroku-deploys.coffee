module.exports = (robot) ->
  room = '13693_development@chat.hipchat.com'

  app_map =
    'lift-jarvis':   'Jarvïs Bötman'
    'lift-rolodex':  'Rolodex'

  robot.router.post '/heroku/deploy', (req, res) ->
    app = app_map[req.body.app]
    robot.messageRoom room, "#{app} was leveled up by #{req.body.user}!"

