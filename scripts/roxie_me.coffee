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
rand = Math.floor(Math.random()*10)

module.exports = (robot) ->

  robot.respond /(Roxie)( me)? (.*)/i, (msg) ->
    msg.http("http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=" + queries[rand])
      .get() (err, response, body) ->        
        msg.send JSON.parse(body).responseData.results[Math.floor(Math.random()*4)].unescapedUrl
        
          



