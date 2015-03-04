# Description:
#   Data Storage library
#
# Dependencies:
#   Underscore
#
# Configuration:
#   none
#
# Commands:
#   none
#
# Author:
#   amdtech

_ = require 'underscore'

config =
  storage_namespace: process.env.HUBOT_STORAGE_NAMESPACE || 'storage'

module.exports = (robot) ->
  class Storage
    # Public: Constructor
    #
    # robot - hubot instance
    # namespace - the namespace for this storage instance
    #
    # Returns an instance
    constructor: (@robot) ->
      @cache = {}
      @robot.brain.on 'loaded', =>
        if @robot.brain.data[config.storage_namespace]
          @cache = @robot.brain.data[config.storage_namespace]

    # Internal: Wraps a method in a save
    #
    # func - a function to wrap
    #
    # Returns nothing
    save_after: ->
      @robot.brain.data[config.storage_namespace] = @cache

    # Internal: Migrate old storage setup into this library
    #
    # namespace - namespace for the storage group
    #
    # Returns nothing
    migrate: (namespace) ->
      if namespace != config.storage_namespace
        @cache[namespace] ?= @robot.brain.data[namespace]
        delete @robot.brain.data[namespace]

    # Public: Stores a value at the given key
    #
    # key - a unique identifier
    # value - anything
    #
    # Returns nothing
    put: (namespace, key, value) ->
      @migrate(namespace)

      @cache[namespace]     ?= {}
      @cache[namespace][key] = value

      @save_after()

    # Public: Gets the value at a specific key
    #
    # key - a key to search for
    #
    # Returns the value
    get: (namespace, key) ->
      @migrate(namespace)

      @cache[namespace]?[key]

    # Public: Removes the value for a given key
    #
    # key - the key to remove
    #
    # Returns nothing
    remove: (namespace, key) ->
      @migrate(namespace)

      delete @cache[namespace]?[key]
      @save_after

    # Public: Get all stored keys
    #
    # Returns an Array of keys
    keys: (namespace) ->
      @migrate(namespace)

      _.keys @cache[namespace]

  robot.storage = new Storage robot
