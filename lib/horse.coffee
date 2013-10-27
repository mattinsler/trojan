fs = require 'fs'
path = require 'path'
Module = require 'module'

install_bulkhead = ->
  return if Module.__packaged_source__?
  
  Module.__packaged_source__ = {}
  
  wrap(fs, 'readFileSync', fs_read_file_sync)
  wrap(fs, 'realpathSync', fs_realpath_sync)
  wrap(fs, 'statSync', fs_stat_sync)
  wrap(fs, 'lstatSync', fs_stat_sync)
  wrap(fs, 'fstatSync', fs_stat_sync)
  wrap(fs, 'existsSync', fs_exists_sync)
  
  # Object.keys(Module).forEach (k) -> wrap(Module, k, mock(k))
  # Object.keys(Module._extensions).forEach (k) -> wrap(Module._extensions, k, mock)
  # Object.keys(fs).forEach (k) -> wrap(fs, k, mock('fs.' + k))

mock = (method_name) ->
  (old_fn) ->
    console.log '[' + method_name + '] CALL:', Array::slice.call(arguments, 1)
    res = old_fn(Array::slice.call(arguments, 1)...)
    console.log '[' + method_name + '] RESULT:', res
    res

wrap = (obj, method_name, fn) ->
  return unless obj[method_name]? and typeof obj[method_name] is 'function'
  
  old_method = obj[method_name].bind(obj)
  
  obj[method_name] = ->
    args = Array::slice.call(arguments)
    fn.apply(obj, [old_method].concat(args))

lookup_file = (filename) ->
  filename = filename.slice(__dirname.length) if filename.indexOf(__dirname) is 0
  
  lookup = Module.__packaged_source__[filename]
  unless lookup?
    err = new Error("ENOENT, no such file or directory '#{filename}'")
    err.code = 'ENOENT'
    throw err
  
  lookup

fs_exists_sync = (old_fn, filename) ->
  try
    lookup_file(filename)
    true
  catch err
    false

fs_realpath_sync = (old_fn, filename, cache) ->
  return old_fn(filename) unless filename.indexOf(__dirname + path.sep) is 0
  filename

get_encoding = (encoding_or_options) ->
  return null unless encoding_or_options?
  return encoding_or_options if typeof encoding_or_options is 'string'
  return encoding_or_options.encoding if encoding_or_options.encoding?
  null

fs_read_file_sync = (old_fn, filename, encoding_or_options) ->
  return old_fn(filename, encoding_or_options) unless filename.indexOf(__dirname + path.sep) is 0
  
  lookup = lookup_file(filename)
  encoding = get_encoding(encoding_or_options)
  content = new Buffer(lookup.data, 'base64')
  content = content.toString(encoding) if encoding?
  
  content

create_stats = (o) ->
  stat = {}
  ['dev', 'mode', 'nlink', 'uid', 'gid', 'rdev', 'blksize', 'ino', 'size', 'blocks'].forEach (k) -> stat[k] = o[k]
  ['atime', 'mtime', 'ctime'].forEach (k) -> stat[k] = new Date(o[k])
  ['isFile', 'isDirectory', 'isBlockDevice', 'isCharacterDevice', 'isSymbolicLink', 'isFIFO', 'isSocket'].forEach (k) -> stat[k] = -> o[k]
  stat

fs_stat_sync = (old_fn, filename) ->
  return old_fn(filename) unless filename.indexOf(__dirname + path.sep) is 0
  
  lookup = lookup_file(filename)
  create_stats(lookup.stat)


install_bulkhead()

delete Module._cache[module.id]
module.exports = require(__filename)
