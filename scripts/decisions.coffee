# Description:
#   Help us decide
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot throw a coin  - Gives you heads or tails
#   hubot flip a coin   - Gives you heads or tails
#   hubot toss a coin   - Gives you heads or tails
#   hubot decide for us - makes a decision
#
# Credits:
#   mrtazz coin.coffee

thecoin = ["heads", "tails"]
yesno = [
  "Signs point to yes.",
  "Yes.",
  "Reply hazy, try again.",
  "Without a doubt.",
  "My sources say no.",
  "As I see it, yes.",
  "You may rely on it.",
  "Concentrate and ask again.",
  "Outlook not so good.",
  "It is decidedly so.",
  "Better not tell you now.",
  "Very doubtful.",
  "Yes - definitely.",
  "It is certain. ",
  "Cannot predict now.",
  "Most likely.",
  "Ask again later.",
  "My reply is no.",
  "Outlook good.",
  "Don't count on it."
]

sassy = [
  "Meh",
  "I'm not so sure...",
  "Let's revisit this tomorrow.",
  "When in doubt, go fast!",
  "Go with your gut.",
  "Be water.",
  "Yeah, sure...",
  "Whatevs.",
  "Ha! Hell to the no.",
  "Yeah right.",
  "Talk to the hand."
]

module.exports = (robot) ->
  robot.respond /(throw|flip|toss) a coin/i, (msg) ->
    msg.reply msg.random thecoin

  robot.respond /should (we|i) (do|try)?/i, (msg) ->
    msg.send msg.random sassy

  robot.respond /decide for us/i, (msg) ->
    msg.send msg.random yesno

  robot.respond /(will|is) (.*)\?$/i, (msg) ->
    msg.send msg.random yesno
