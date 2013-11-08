Module = require 'module'

return if Module.__trojan_source__?
Module.__trojan_source__ = {}

fs = require 'fs'
path = require 'path'

# errors

ENOENT = (filename) ->
  err = new Error("ENOENT, no such file or directory '#{filename}'")
  err.code = 'ENOENT'
  err

EISDIR = (filename) ->
  err = new Error("EISDIR, illegal operation on a directory")
  err.code = 'EISDIR'
  err

ENOTDIR = (filename) ->
  err = new Error("ENOTDIR, not a directory '#{filename}'")
  err.code = 'ENOTDIR'
  err

# helpers

get_file_ref = (filename) ->
  a = Object.keys(Module.__trojan_source__)
  .map (f) ->
    return null unless filename.length > f.length
    return null unless f + '/' is filename.slice(0, f.length + 1)
    {
      root: f
      path: filename.slice(f.length)
    }
  .filter (f) -> f?
  
  return null if a.length is 0
  
  max = a[0].root.length
  b = a[0]
  for i in a
    if i.root.length > max
      max = i.root.length
      b = i
  {
    tree: Module.__trojan_source__[b.root]
    path: b.path
  }

get_file = (filename) ->
  # console.log '------ GET FILE', filename
  o = get_file_ref(filename)
  res = {is_packaged: o?}
  res.path = o?.path if o?.path?
  res.file = o.tree[o.path] if o?.tree?[o.path]?
  # console.log '------ GET FILE', res
  res

get_encoding = (encoding_or_options) ->
  return null unless encoding_or_options?
  return encoding_or_options if typeof encoding_or_options is 'string'
  return encoding_or_options.encoding if encoding_or_options.encoding?
  null

create_stats = (o) ->
  stat = {}
  ['dev', 'mode', 'nlink', 'uid', 'gid', 'rdev', 'blksize', 'ino', 'size', 'blocks'].forEach (k) -> stat[k] = o[k]
  ['atime', 'mtime', 'ctime'].forEach (k) -> stat[k] = new Date(o[k])
  ['isFile', 'isDirectory', 'isBlockDevice', 'isCharacterDevice', 'isSymbolicLink', 'isFIFO', 'isSocket'].forEach (k) -> stat[k] = -> o[k]
  stat

# fs implementations

fs_readdir_sync = (old_fn, filename) ->
  o = get_file(filename)
  return old_fn(filename) unless o.is_packaged
  throw ENOENT(filename) unless o.file?
  throw ENOTDIR(filename) unless o.file.type is 'dir'
  
  o.file.children.map (f) -> f.slice(o.path.length + 1)

fs_exists_sync = (old_fn, filename) ->
  o = get_file(filename)
  return old_fn(filename) unless o.is_packaged
  o.file?

fs_realpath_sync = (old_fn, filename, cache) ->
  return old_fn(filename) unless get_file_ref(filename)?
  filename

fs_read_file_sync = (old_fn, filename, encoding_or_options) ->
  o = get_file(filename)
  return old_fn(filename, encoding_or_options) unless o.is_packaged
  throw ENOENT(filename) unless o.file?
  throw EISDIR(filename) if o.file.type is 'dir'
  
  encoding = get_encoding(encoding_or_options)
  content = new Buffer(o.file.data, 'base64')
  content = content.toString(encoding) if encoding?
  
  content

fs_stat_sync = (old_fn, filename) ->
  o = get_file(filename)
  return old_fn(filename) unless o.is_packaged
  
  create_stats(o.file.stat)




# instrument fs

wrap = (obj, method_name, fn) ->
  return unless obj[method_name]? and typeof obj[method_name] is 'function'
  
  old_method = obj[method_name].bind(obj)
  
  obj[method_name] = ->
    # console.log "[#{method_name}]", arguments
    args = Array::slice.call(arguments)
    fn.apply(obj, [old_method].concat(args))

wrap(fs, 'readFileSync', fs_read_file_sync)
wrap(fs, 'realpathSync', fs_realpath_sync)
wrap(fs, 'statSync', fs_stat_sync)
wrap(fs, 'lstatSync', fs_stat_sync)
wrap(fs, 'fstatSync', fs_stat_sync)
wrap(fs, 'existsSync', fs_exists_sync)
wrap(fs, 'readdirSync', fs_readdir_sync)
