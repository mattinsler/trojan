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
    return null if path.basename(dir)[0] is '.'
    
    children = []
    
    for file in fs.readdirSync(dir)
      file_path = path.join(dir, file)
      if fs.statSync(file_path).isDirectory()
        children.push(@build_dir(file_path, source_tree))
      else
        children.push(@build_file(file_path, source_tree))
    
    relative_path = dir.slice(@root.length) or '/'
    source_tree[relative_path] =
      type: 'dir'
      stat: stat_file(dir)
      children: children.filter((f) -> f?)
    
    relative_path
  
  build_file: (file, source_tree = {}) ->
    return null if path.basename(file)[0] is '.'
    
    relative_path = file.slice(@root.length) or '/'
    source_tree[relative_path] =
      type: 'file'
      stat: stat_file(file)
      data: fs.readFileSync(file).toString('base64')
    relative_path
  
  build: ->
    tree = {}
    @build_dir(@root, tree)
    tree

module.exports = Builder
