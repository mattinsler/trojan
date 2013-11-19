var EISDIR, ENOENT, ENOTDIR, EPERM, Module, create_stats, crypto, fs, fs_exists, fs_read_file, fs_readdir, fs_realpath, fs_rmdir, fs_stat, fs_unlink, fs_utimes, get_encoding, get_file, get_file_ref, home_directory, is_windows, node_extension, path, temp_directory, windows_dir, wrap, wrap_fn, wrap_up,
  __slice = [].slice;

Module = require('module');

if (Module.__trojan_source__ != null) {
  return;
}

Module.__trojan_source__ = {};

fs = require('fs');

path = require('path');

crypto = require('crypto');

is_windows = process.platform === 'win32';

windows_dir = is_windows ? process.env.windir || 'C:\\Windows' : null;

home_directory = function() {
  if (is_windows) {
    return process.env.USERPROFILE;
  } else {
    return process.env.HOME;
  }
};

temp_directory = function() {
  var home, t, tmp;
  tmp = process.env.TMPDIR || process.env.TMP || process.env.TEMP;
  if (tmp != null) {
    return tmp;
  }
  t = is_windows ? 'temp' : 'tmp';
  home = home_directory();
  if (home != null) {
    return path.resolve(home, t);
  }
  if (is_windows) {
    return path.resolve(windows_dir, t);
  }
  return '/tmp';
};

ENOENT = function(filename) {
  var err;
  err = new Error("ENOENT, no such file or directory '" + filename + "'");
  err.code = 'ENOENT';
  return err;
};

EISDIR = function(filename) {
  var err;
  err = new Error("EISDIR, illegal operation on a directory");
  err.code = 'EISDIR';
  return err;
};

ENOTDIR = function(filename) {
  var err;
  err = new Error("ENOTDIR, not a directory '" + filename + "'");
  err.code = 'ENOTDIR';
  return err;
};

EPERM = function(filename) {
  var err;
  err = new Error("EPERM, operation not permitted '" + filename + "'");
  err.code = 'ENOTDIR';
  return err;
};

get_file_ref = function(filename) {
  var a, b, i, max, _i, _len;
  if (filename == null) {
    return null;
  }
  a = Object.keys(Module.__trojan_source__).map(function(f) {
    if (!(filename.length > f.length)) {
      return null;
    }
    if (f + '/' !== filename.slice(0, f.length + 1)) {
      return null;
    }
    return {
      root: f,
      path: filename.slice(f.length)
    };
  }).filter(function(f) {
    return f != null;
  });
  if (a.length === 0) {
    return null;
  }
  max = a[0].root.length;
  b = a[0];
  for (_i = 0, _len = a.length; _i < _len; _i++) {
    i = a[_i];
    if (i.root.length > max) {
      max = i.root.length;
      b = i;
    }
  }
  return {
    root: b.root,
    tree: Module.__trojan_source__[b.root],
    path: b.path
  };
};

get_file = function(filename) {
  var o, res;
  o = get_file_ref(filename);
  res = {
    is_packaged: o != null
  };
  if (o != null) {
    res.root = o.root;
    res.tree = o.tree;
    res.path = o.path;
    res.file = o.tree[o.path];
  }
  return res;
};

get_encoding = function(encoding_or_options) {
  if (encoding_or_options == null) {
    return null;
  }
  if (typeof encoding_or_options === 'string') {
    return encoding_or_options;
  }
  if (encoding_or_options.encoding != null) {
    return encoding_or_options.encoding;
  }
  return null;
};

create_stats = function(o) {
  var stat;
  stat = {};
  ['dev', 'mode', 'nlink', 'uid', 'gid', 'rdev', 'blksize', 'ino', 'size', 'blocks'].forEach(function(k) {
    return stat[k] = o[k];
  });
  ['atime', 'mtime', 'ctime'].forEach(function(k) {
    return stat[k] = new Date(o[k]);
  });
  ['isFile', 'isDirectory', 'isBlockDevice', 'isCharacterDevice', 'isSymbolicLink', 'isFIFO', 'isSocket'].forEach(function(k) {
    return stat[k] = function() {
      return o[k];
    };
  });
  return stat;
};

fs_exists = function(o, filename) {
  return o.file != null;
};

fs_readdir = function(o, filename) {
  if (o.file == null) {
    throw ENOENT(filename);
  }
  if (o.file.type !== 'dir') {
    throw ENOTDIR(filename);
  }
  return o.file.children.map(function(f) {
    return f.slice(o.path.length + 1);
  });
};

fs_read_file = function(o, filename, encoding_or_options) {
  var content, encoding;
  if (o.file == null) {
    throw ENOENT(filename);
  }
  if (o.file.type === 'dir') {
    throw EISDIR(filename);
  }
  encoding = get_encoding(encoding_or_options);
  content = new Buffer(o.file.data, 'base64');
  if (encoding != null) {
    content = content.toString(encoding);
  }
  return content;
};

fs_realpath = function(o, filename, cache) {
  return filename;
};

fs_rmdir = function(o, filename) {
  if (o.file == null) {
    throw ENOENT(filename);
  }
  if (o.file.type !== 'dir') {
    throw ENOTDIR(filename);
  }
  return delete o.tree[o.path];
};

fs_stat = function(o, filename) {
  if (o.file == null) {
    throw ENOENT(filename);
  }
  return create_stats(o.file.stat);
};

fs_unlink = function(o, filename) {
  if (o.file == null) {
    throw ENOENT(filename);
  }
  if (o.file.type !== 'file') {
    throw EPERM(filename);
  }
  return delete o.tree[o.path];
};

fs_utimes = function(o, filename, atime, mtime) {
  if (o.file == null) {
    throw ENOENT(filename);
  }
  o.file.stat.atime = new Date(atime).getTime();
  return o.file.stat.mtime = new Date(mtime).getTime();
};

node_extension = function(old_fn, module, filename) {
  var err, o, tmp_file, tmp_root;
  o = get_file(filename);
  if (!(o.is_packaged && path.extname(filename) === '.node')) {
    return old_fn(module, filename);
  }
  tmp_root = crypto.createHash('sha1').update(o.root).digest('hex');
  tmp_file = path.join(tmp_root, path.basename(filename));
  try {
    fs.mkdirSync(tmp_root);
  } catch (_error) {
    err = _error;
  }
  fs.writeFileSync(tmp_file, fs.readFileSync(filename));
  return old_fn(module, tmp_file);
};

wrap_fn = function(obj, method_name, fn) {
  var old_fn;
  if (!((obj[method_name] != null) && typeof obj[method_name] === 'function')) {
    return;
  }
  old_fn = obj[method_name].bind(obj);
  return obj[method_name] = function() {
    var args;
    args = Array.prototype.slice.call(arguments);
    return fn.apply(null, [old_fn].concat(__slice.call(args)));
  };
};

wrap = function(obj, method_name, fn, is_async) {
  var old_fn;
  if (is_async == null) {
    is_async = false;
  }
  if (!((obj[method_name] != null) && typeof obj[method_name] === 'function')) {
    return;
  }
  old_fn = obj[method_name].bind(obj);
  return obj[method_name] = function() {
    var args, callback, o;
    args = Array.prototype.slice.call(arguments);
    o = get_file(args[0]);
    if (is_async) {
      if (typeof args[args.length - 1] === 'function') {
        callback = args.pop();
      }
      if (!o.is_packaged) {
        return old_fn.apply(null, __slice.call(args).concat([callback]));
      }
      return setTimeout(function() {
        var err;
        try {
          return callback(null, fn.apply(null, [o].concat(__slice.call(args))));
        } catch (_error) {
          err = _error;
          return callback(err);
        }
      }, 1);
    } else {
      if (!o.is_packaged) {
        return old_fn.apply(null, args);
      }
      return fn.apply(null, [o].concat(__slice.call(args)));
    }
  };
};

wrap_up = function(obj, method_name, fn) {
  wrap(obj, method_name, fn, true);
  return wrap(obj, method_name + 'Sync', fn);
};

wrap_up(fs, 'exists', fs_exists);

wrap_up(fs, 'readdir', fs_readdir);

wrap_up(fs, 'readFile', fs_read_file);

wrap_up(fs, 'realpath', fs_realpath);

wrap_up(fs, 'rmdir', fs_rmdir);

wrap_up(fs, 'stat', fs_stat);

wrap_up(fs, 'lstat', fs_stat);

wrap_up(fs, 'fstat', fs_stat);

wrap_up(fs, 'unlink', fs_unlink);

wrap_up(fs, 'utimes', fs_utimes);

wrap_fn(Module._extensions, '.node', node_extension);
