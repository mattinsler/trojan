(function() {
  var Builder, PackageBuilder, coffee, fs, horse_source, path, shell;

  fs = require('fs');

  path = require('path');

  shell = require('shelljs');

  coffee = require('coffee-script');

  Builder = require('./builder');

  horse_source = fs.readFileSync(path.join(__dirname, '..', 'lib', 'horse.coffee')).toString();

  PackageBuilder = (function() {
    function PackageBuilder(root) {
      this.root = root;
      this.root = path.resolve(this.root);
    }

    PackageBuilder.prototype.build = function() {
      var builder, data, main, pkg, source, target_root;
      if (!fs.existsSync(this.root)) {
        throw new Error(this.root + ' is not a valid directory');
      }
      if (!fs.statSync(this.root).isDirectory()) {
        throw new Error(this.root + ' is not a valid directory');
      }
      target_root = this.root + '-trojan';
      shell.rm('-rf', target_root);
      shell.mkdir('-p', target_root);
      shell.cd(this.root);
      shell.cp('-r', shell.ls('*').filter(function(f) {
        return f[0] !== '.' && f !== 'node_modules';
      }), target_root + '/');
      shell.cd(target_root);
      shell.exec('npm install --production');
      pkg = require(path.join(target_root, 'package.json'));
      main = path.join(target_root, pkg.main || 'index');
      builder = new Builder(target_root);
      source = builder.build();
      data = horse_source.replace('Module.__packaged_source__ = {}', 'Module.__packaged_source__ = ' + JSON.stringify(source));
      data = data.replace('module.exports = require(__filename)', 'module.exports = require("' + main + '")');
      data = coffee.compile(data);
      pkg.dependencies = {};
      pkg.devDependencies = {};
      pkg.main = 'index.js';
      fs.writeFileSync(path.join(target_root, 'index.js'), data);
      fs.writeFileSync(path.join(target_root, 'package.json'), JSON.stringify(pkg, null, 2));
      shell.rm('-rf', shell.ls('*').filter(function(f) {
        return f !== 'index.js' && f !== 'package.json';
      }));
      return target_root;
    };

    return PackageBuilder;

  })();

  module.exports = PackageBuilder;

}).call(this);
