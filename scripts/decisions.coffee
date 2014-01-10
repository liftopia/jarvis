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
#   hubot throw flip toss a coin - Gives you heads or tails
#   hubot decide for us - makes a decision
#
# Credits:
#   mrtazz coin.coffee

thecoin = ["heads", "tails"]
decisions = [
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
  "Better not tell you now. ",
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

module.exports = (robot) ->
  robot.respond /(throw|flip|toss) a coin/i, (msg) ->
    msg.reply msg.random thecoin

  robot.respond /decide for us/i, (msg) ->
    msg.send msg.random decisions
