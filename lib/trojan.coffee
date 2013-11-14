Builder = exports.Builder = require './builder'
PackageBuilder = exports.PackageBuilder = require './package_builder'

exports.create_package = (root, opts) -> new PackageBuilder(root, opts).build()
