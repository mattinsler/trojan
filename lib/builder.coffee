fs = require 'fs'
path = require 'path'

stat_file = (file) ->
  o = fs.statSync(file)
  stat = JSON.parse(JSON.stringify(o))
  ['isFile', 'isDirectory', 'isBlockDevice', 'isCharacterDevice', 'isSymbolicLink', 'isFIFO', 'isSocket'].forEach (k) ->
    try
      stat[k] = o[k]()
    catch err
  stat

class Builder
  constructor: (@root) ->
    @root = path.resolve(@root)
  
  build_dir: (dir, source_tree = {}) ->
    for file in fs.readdirSync(dir)
      file_path = path.join(dir, file)
      if fs.statSync(file_path).isDirectory()
        @build_dir(file_path, source_tree)
      else
        @build_file(file_path, source_tree)
    source_tree
  
  build_file: (file, source_tree = {}) ->
    relative_path = file.slice(@root.length)
    source_tree[relative_path] =
      stat: stat_file(file)
      data: fs.readFileSync(file).toString('base64')
    source_tree
  
  build: ->
    @build_dir(@root)

module.exports = Builder
