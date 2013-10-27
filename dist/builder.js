(function() {
  var Builder, fs, path, stat_file;

  fs = require('fs');

  path = require('path');

  stat_file = function(file) {
    var o, stat;
    o = fs.statSync(file);
    stat = JSON.parse(JSON.stringify(o));
    ['isFile', 'isDirectory', 'isBlockDevice', 'isCharacterDevice', 'isSymbolicLink', 'isFIFO', 'isSocket'].forEach(function(k) {
      var err;
      try {
        return stat[k] = o[k]();
      } catch (_error) {
        err = _error;
      }
    });
    return stat;
  };

  Builder = (function() {
    function Builder(root) {
      this.root = root;
      this.root = path.resolve(this.root);
    }

    Builder.prototype.build_dir = function(dir, source_tree) {
      var file, file_path, _i, _len, _ref;
      if (source_tree == null) {
        source_tree = {};
      }
      _ref = fs.readdirSync(dir);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        file = _ref[_i];
        file_path = path.join(dir, file);
        if (fs.statSync(file_path).isDirectory()) {
          this.build_dir(file_path, source_tree);
        } else {
          this.build_file(file_path, source_tree);
        }
      }
      return source_tree;
    };

    Builder.prototype.build_file = function(file, source_tree) {
      var relative_path;
      if (source_tree == null) {
        source_tree = {};
      }
      relative_path = file.slice(this.root.length);
      source_tree[relative_path] = {
        stat: stat_file(file),
        data: fs.readFileSync(file).toString('base64')
      };
      return source_tree;
    };

    Builder.prototype.build = function() {
      return this.build_dir(this.root);
    };

    return Builder;

  })();

  module.exports = Builder;

}).call(this);
