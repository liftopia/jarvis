# Description:
#   Github Handler
#
# Dependencies:
#   github
#   Underscore
#
# Configuration:
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_USER
#   HUBOT_GITHUB_API
#   HUBOT_GITHUB_ORG
#   HUBOT_REPOS_LOOKUP
#
# Commands:
#   none
#
# Author:
#   amdtech

gh                  = require('github')
github              = new gh({ version: "3.0.0", protocol: "https" })
default_github_user = process.env.HUBOT_GITHUB_USER

github.authenticate { type: "oauth", token: process.env.HUBOT_GITHUB_TOKEN }

# borrowed from githubot
qualified_repo = (repo) ->
  return null unless repo?
  repo = repo.toLowerCase()
  return repo unless repo.indexOf("/") is -1
  return repo unless (user = default_github_user)?
  "#{user}/#{repo}"

clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime())

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()
  newInstance[key] = clone obj[key] for key of obj
  newInstance

handle_error = (msg, message, err) ->
  if err?
    msg.send "#{message}: #{JSON.parse(err).message}"

module.exports = (robot) ->
  robot.on 'github:issues:createComment', (msg, options) ->
    github.issues.createComment options, (err, comment) =>
      handle_error(msg, "Issue posting comment", err)

  robot.on 'github:pullRequests:merge', (msg, options) ->
    github.pullRequests.merge options, (err, merge) =>
      handle_error(msg, "Issue merging pull request", err)
