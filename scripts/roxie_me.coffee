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
queries = ["yorkies", "yorkie+puppies", "yorkie", "yorkie+sleeping", "yorkie+playing", "yorkie+jumping" 
          , "yorkie+costume", "yorkie+halloween", "yorkie+teacup", "yorkie+trouble"]

module.exports = (robot) ->
  robot.respond /roxie me/i, (msg) ->
    msg.http("http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=" + msg.random queries)
      .get() (err, response, body) ->
        yorkies = msg.random JSON.parse(body).responseData.results
        if JSON.parse(body).responseData.results.length == 0
          msg.send 'The Yorkies are hiding, try again later'
        else
          msg.send yorkies.unescapedUrl