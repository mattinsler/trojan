(function() {
  var Builder, PackageBuilder;

  Builder = exports.Builder = require('./builder');

  PackageBuilder = exports.PackageBuilder = require('./package_builder');

  exports.create_package = function(root) {
    return new PackageBuilder(root).build();
  };

}).call(this);
