# Commands
# Hubot roxie me - returns a yorkie
# 
# Description
# Returns images of yorkies from google
# Happy Bday Jenn PC
#
# Author 
# ryanwaters
#
queries = [
  "yorkies"
  "yorkie+puppies"
  "yorkie"
  "yorkie+sleeping" 
  "yorkie+playing"
  "yorkie+jumping" 
  "yorkie+costume"
  "yorkie+halloween"
  "yorkie+teacup"
  "yorkie+trouble"
]

module.exports = (robot) ->
  robot.respond /roxie me/i, (msg) ->
    query = msg.random(queries)
    robot.http("http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=#{query}")
      .get() (err, response, body) ->
        yorkies = msg.random JSON.parse(body).responseData.results
        if yorkies.length is 0
          msg.send 'The Yorkie well has run dry, check back later'
        else
          msg.send yorkies.unescapedUrl