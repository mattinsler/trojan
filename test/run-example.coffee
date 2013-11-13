path = require 'path'
{Builder} = require '../'

root = path.join(__dirname, '..', 'example')

builder = new Builder(root)
source = builder.build()

app = require('../lib/horse')(
  path.dirname(__filename),
  source,
  'server.coffee'
)

app.listen(3000)
