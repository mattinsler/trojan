fs = require 'fs'
path = require 'path'
shell = require 'shelljs'
coffee = require 'coffee-script'
Builder = require './builder'

files =
  'horse.js': coffee.compile(fs.readFileSync(path.join(__dirname, 'horse.coffee'), 'utf8'), bare: true)
  'bulkhead.js': coffee.compile(fs.readFileSync(path.join(__dirname, 'bulkhead.coffee'), 'utf8'), bare: true)

class PackageBuilder
  constructor: (@root) ->
    @root = path.resolve(@root)
  
  build: ->
    throw new Error(@root + ' is not a valid directory') unless fs.existsSync(@root)
    throw new Error(@root + ' is not a valid directory') unless fs.statSync(@root).isDirectory()
    
    target_root = @root + '-trojan'
  
    shell.rm('-rf', target_root)
    shell.mkdir('-p', target_root)
  
    shell.cd(@root)
    shell.cp('-r', shell.ls('*').filter((f) -> f[0] isnt '.' and f isnt 'node_modules'), target_root + '/')
  
    shell.cd(target_root)
    shell.exec('npm install --production')
  
    pkg = require(path.join(target_root, 'package.json'))
    main = pkg.main or 'index'
  
    builder = new Builder(target_root)
    source = builder.build()
  
    pkg.dependencies = {}
    pkg.devDependencies = {}
    pkg.main = '__trojan__/bootstrap.js'
    
    shell.mkdir('-p', path.join(target_root, '__trojan__'))
    fs.writeFileSync(path.join(target_root, '__trojan__', k), v) for k, v of files
    
    fs.writeFileSync(path.join(target_root, '__trojan__', 'source_code.js'), 'module.exports = ' + JSON.stringify(source) + ';')
    fs.writeFileSync(path.join(target_root, '__trojan__', 'bootstrap.js'), """
    module.exports = require('./horse')(
      require('path').dirname(__dirname),
      require('./source_code'),
      '#{main}'
    );
    """)
    fs.writeFileSync(path.join(target_root, 'package.json'), JSON.stringify(pkg, null, 2))
  
    shell.rm('-rf', shell.ls('*').filter((f) -> f not in ['__trojan__', 'package.json']))
    
    target_root

module.exports = PackageBuilder
