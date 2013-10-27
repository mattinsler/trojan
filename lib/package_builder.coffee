fs = require 'fs'
path = require 'path'
shell = require 'shelljs'
coffee = require 'coffee-script'
Builder = require './builder'

horse_source = fs.readFileSync(path.join(__dirname, '..', 'lib', 'horse.coffee')).toString()

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
    main = path.join(target_root, (pkg.main or 'index'))
  
    builder = new Builder(target_root)
    source = builder.build()
    data = horse_source.replace('Module.__packaged_source__ = {}', 'Module.__packaged_source__ = ' + JSON.stringify(source))
    data = data.replace('module.exports = require(__filename)', 'module.exports = require("' + main + '")')
    data = coffee.compile(data)
  
    pkg.dependencies = {}
    pkg.devDependencies = {}
    pkg.main = 'index.js'
  
    fs.writeFileSync(path.join(target_root, 'index.js'), data)
    fs.writeFileSync(path.join(target_root, 'package.json'), JSON.stringify(pkg, null, 2))
  
    shell.rm('-rf', shell.ls('*').filter((f) -> f not in ['index.js', 'package.json']))
    
    target_root

module.exports = PackageBuilder
