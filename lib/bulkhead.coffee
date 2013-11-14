Module = require 'module'

return if Module.__trojan_source__?
Module.__trojan_source__ = {}

fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
is_windows = process.platform is 'win32'
windows_dir = if is_windows then process.env.windir or 'C:\\Windows' else null

home_directory = ->
  if is_windows then process.env.USERPROFILE else process.env.HOME

temp_directory = ->
  tmp = process.env.TMPDIR or process.env.TMP or process.env.TEMP
  return tmp if tmp?
  
  t = if is_windows then 'temp' else 'tmp'
  home = home_directory()
  return path.resolve(home, t) if home?
  return path.resolve(windows_dir, t) if is_windows
  '/tmp'


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

EPERM = (filename) ->
  err = new Error("EPERM, operation not permitted '#{filename}'")
  err.code = 'ENOTDIR'
  err

# helpers

get_file_ref = (filename) ->
  return null unless filename?
  
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
    root: b.root
    tree: Module.__trojan_source__[b.root]
    path: b.path
  }

get_file = (filename) ->
  # console.log '------ GET FILE', filename
  o = get_file_ref(filename)
  res = {is_packaged: o?}
  
  if o?
    res.root = o.root
    res.tree = o.tree
    res.path = o.path
    res.file = o.tree[o.path]
  
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

fs_exists = (o, filename) ->
  o.file?

fs_readdir = (o, filename) ->
  throw ENOENT(filename) unless o.file?
  throw ENOTDIR(filename) unless o.file.type is 'dir'
  
  o.file.children.map (f) -> f.slice(o.path.length + 1)

fs_read_file = (o, filename, encoding_or_options) ->
  throw ENOENT(filename) unless o.file?
  throw EISDIR(filename) if o.file.type is 'dir'
  
  encoding = get_encoding(encoding_or_options)
  content = new Buffer(o.file.data, 'base64')
  content = content.toString(encoding) if encoding?
  
  content

fs_realpath = (o, filename, cache) ->
  filename

fs_rmdir = (o, filename) ->
  throw ENOENT(filename) unless o.file?
  throw ENOTDIR(filename) unless o.file.type is 'dir'
  
  delete o.tree[o.path]

fs_stat = (o, filename) ->
  throw ENOENT(filename) unless o.file?
  
  create_stats(o.file.stat)

fs_unlink = (o, filename) ->
  throw ENOENT(filename) unless o.file?
  throw EPERM(filename) unless o.file.type is 'file'
  
  delete o.tree[o.path]

fs_utimes = (o, filename, atime, mtime) ->
  throw ENOENT(filename) unless o.file?
  
  o.file.stat.atime = new Date(atime).getTime()
  o.file.stat.mtime = new Date(mtime).getTime()

# Module overrides

node_extension = (old_fn, module, filename) ->
  o = get_file(filename)
  return old_fn(module, filename) unless o.is_packaged and path.extname(filename) is '.node'
  
  tmp_root = crypto.createHash('sha1').update(o.root).digest('hex')
  tmp_file = path.join(tmp_root, path.basename(filename))
  
  try
    fs.mkdirSync(tmp_root)
  catch err
  
  fs.writeFileSync(tmp_file, fs.readFileSync(filename))
  
  old_fn(module, tmp_file)

# instrumentation helpers

wrap_fn = (obj, method_name, fn) ->
  return unless obj[method_name]? and typeof obj[method_name] is 'function'
  
  old_fn = obj[method_name].bind(obj)
  obj[method_name] = ->
    args = Array::slice.call(arguments)
    fn(old_fn, args...)

wrap = (obj, method_name, fn, is_async = false) ->
  return unless obj[method_name]? and typeof obj[method_name] is 'function'
  
  old_fn = obj[method_name].bind(obj)
  obj[method_name] = ->
    # console.log "[#{method_name}]", arguments
    args = Array::slice.call(arguments)
    o = get_file(args[0])
    
    if is_async
      callback = args.pop() if typeof args[args.length - 1] is 'function'
      return old_fn(args..., callback) unless o.is_packaged
      setTimeout ->
        try
          callback(null, fn(o, args...))
        catch err
          callback(err)
      , 1
    else
      return old_fn(args...) unless o.is_packaged
      fn(o, args...)

wrap_up = (obj, method_name, fn) ->
  wrap(obj, method_name,          fn, true)
  wrap(obj, method_name + 'Sync', fn)


wrap_up(fs, 'exists', fs_exists)
wrap_up(fs, 'readdir', fs_readdir)
wrap_up(fs, 'readFile', fs_read_file)
wrap_up(fs, 'realpath', fs_realpath)
wrap_up(fs, 'rmdir', fs_rmdir)
wrap_up(fs, 'stat', fs_stat)
wrap_up(fs, 'lstat', fs_stat)
wrap_up(fs, 'fstat', fs_stat)
wrap_up(fs, 'unlink', fs_unlink)
wrap_up(fs, 'utimes', fs_utimes)

# open, close, read, write, createReadStream, watchFile, unwatchFile, futimes, fsync

wrap_fn(Module._extensions, '.node', node_extension)
