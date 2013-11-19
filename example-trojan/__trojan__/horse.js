var Module, path;

path = require('path');

Module = require('module');

module.exports = function(dirname, source, main) {
  require('./bulkhead');
  if (Module.__trojan_source__[dirname] != null) {
    throw new Error('Already loaded package ' + dirname);
  }
  Module.__trojan_source__[dirname] = source;
  main = path.resolve(dirname, main);
  delete Module._cache[main];
  return require(main);
};
