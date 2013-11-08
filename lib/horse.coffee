path = require 'path'
Module = require 'module'

module.exports = (dirname, source, main) ->
  # install bulkhead
  require './bulkhead'
  
  # install packaged source
  throw new Error('Already loaded package ' + dirname) if Module.__trojan_source__[dirname]?
  Module.__trojan_source__[dirname] = source
  
  main = path.resolve(dirname, main)
  
  # clear and load the new main
  delete Module._cache[main]
  require(main)
