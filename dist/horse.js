(function() {
  var Module, create_stats, fs, fs_exists_sync, fs_read_file_sync, fs_realpath_sync, fs_stat_sync, get_encoding, install_bulkhead, lookup_file, mock, path, wrap;

  fs = require('fs');

  path = require('path');

  Module = require('module');

  install_bulkhead = function() {
    if (Module.__packaged_source__ != null) {
      return;
    }
    Module.__packaged_source__ = {};
    wrap(fs, 'readFileSync', fs_read_file_sync);
    wrap(fs, 'realpathSync', fs_realpath_sync);
    wrap(fs, 'statSync', fs_stat_sync);
    wrap(fs, 'lstatSync', fs_stat_sync);
    wrap(fs, 'fstatSync', fs_stat_sync);
    return wrap(fs, 'existsSync', fs_exists_sync);
  };

  mock = function(method_name) {
    return function(old_fn) {
      var res;
      console.log('[' + method_name + '] CALL:', Array.prototype.slice.call(arguments, 1));
      res = old_fn.apply(null, Array.prototype.slice.call(arguments, 1));
      console.log('[' + method_name + '] RESULT:', res);
      return res;
    };
  };

  wrap = function(obj, method_name, fn) {
    var old_method;
    if (!((obj[method_name] != null) && typeof obj[method_name] === 'function')) {
      return;
    }
    old_method = obj[method_name].bind(obj);
    return obj[method_name] = function() {
      var args;
      args = Array.prototype.slice.call(arguments);
      return fn.apply(obj, [old_method].concat(args));
    };
  };

  lookup_file = function(filename) {
    var err, lookup;
    if (filename.indexOf(__dirname) === 0) {
      filename = filename.slice(__dirname.length);
    }
    lookup = Module.__packaged_source__[filename];
    if (lookup == null) {
      err = new Error("ENOENT, no such file or directory '" + filename + "'");
      err.code = 'ENOENT';
      throw err;
    }
    return lookup;
  };

  fs_exists_sync = function(old_fn, filename) {
    var err;
    try {
      lookup_file(filename);
      return true;
    } catch (_error) {
      err = _error;
      return false;
    }
  };

  fs_realpath_sync = function(old_fn, filename, cache) {
    if (filename.indexOf(__dirname + path.sep) !== 0) {
      return old_fn(filename);
    }
    return filename;
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

  fs_read_file_sync = function(old_fn, filename, encoding_or_options) {
    var content, encoding, lookup;
    if (filename.indexOf(__dirname + path.sep) !== 0) {
      return old_fn(filename, encoding_or_options);
    }
    lookup = lookup_file(filename);
    encoding = get_encoding(encoding_or_options);
    content = new Buffer(lookup.data, 'base64');
    if (encoding != null) {
      content = content.toString(encoding);
    }
    return content;
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

  fs_stat_sync = function(old_fn, filename) {
    var lookup;
    if (filename.indexOf(__dirname + path.sep) !== 0) {
      return old_fn(filename);
    }
    lookup = lookup_file(filename);
    return create_stats(lookup.stat);
  };

  install_bulkhead();

  delete Module._cache[module.id];

  module.exports = require(__filename);

}).call(this);
