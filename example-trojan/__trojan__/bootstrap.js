module.exports = require('./horse')(
  require('path').dirname(__dirname),
  require('./source_code'),
  'server.js'
);