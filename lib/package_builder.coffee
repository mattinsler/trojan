fs = require 'fs'
path = require 'path'
shell = require 'shelljs'
coffee = require 'coffee-script'
Builder = require './builder'

files =
  'horse.js': coffee.compile(fs.readFileSync(path.join(__dirname, 'horse.coffee'), 'utf8'), bare: true)
  'bulkhead.js': coffee.compile(fs.readFileSync(path.join(__dirname, 'bulkhead.coffee'), 'utf8'), bare: true)

class PackageBuilder
  constructor: (@root, @opts = {}) ->
    @root = path.resolve(@root)
  
  build: ->
    throw new Error(@root + ' is not a valid directory') unless fs.existsSync(@root)
    throw new Error(@root + ' is not a valid directory') unless fs.statSync(@root).isDirectory()
    
    target_root = @root + '-trojan'
    
    pkg = require(path.join(@root, 'package.json'))
    main = pkg.main or 'index'
    
    shell.rm('-rf', target_root)
    shell.mkdir('-p', target_root)
    
    cp_files = shell.ls(path.join(@root, '*')).filter (f) ->
      base = path.basename(f)
      base[0] isnt '.' and base isnt 'node_modules'
    shell.cp('-r', cp_files, target_root)
    
    if @opts['use-modules'] is true
      shell.mkdir('-p', path.join(target_root, 'node_modules'))
      dep_files = Object.keys(pkg.dependencies).map((d) => path.join(@root, 'node_modules', d))
      console.log dep_files
      shell.cp('-r', dep_files, path.join(target_root, 'node_modules'))
    else
      shell.cd(target_root)
      shell.exec('npm install --production')
    
    console.log 'HEY'
    
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
