path = require 'path'
bcrypt = require 'bcrypt'
express = require 'express'
passport = require 'passport'
LocalStrategy = require('passport-local').Strategy

USERS =
  1:
    id: 1
    username: 'admin'
    password: bcrypt.hashSync('secure', 10)
  2:
    id: 2
    username: 'foo'
    password: bcrypt.hashSync('barbaz', 10)

USERS_BY_USERNAME = Object.keys(USERS).reduce (o, k) ->
  o[USERS[k].username] = USERS[k]
  o
, {}

passport.use new LocalStrategy(
  (username, password, done) ->
    user = USERS_BY_USERNAME[username]
    return done(null, false) unless user?
    return done(null, false) unless bcrypt.compareSync(password, user.password)
    done(null, user)
)

passport.serializeUser (user, done) ->
  done(null, user.id)

passport.deserializeUser (id, done) ->
  done(null, USERS[id])

app = express()

app.set('view engine', 'ejs')
app.set('views', path.join(__dirname, 'templates'))

app.use express.logger()
app.use express.bodyParser()
app.use express.methodOverride()
app.use express.cookieParser()
app.use express.session(secret: 'shhhhhhhhhhhhhhhh')
app.use passport.initialize()
app.use passport.session()
app.use app.router

app.engine('html', require('ejs').renderFile)

app.get '/', (req, res, next) ->
  return res.redirect('/login') unless req.user?
  res.render('index.html.ejs', user: req.user)

app.get  '/login', (req, res, next) -> res.render('login.html')
app.post '/login', passport.authenticate('local', successRedirect: '/', failureRedirect: '/login')
app.get  '/logout', (req, res, next) ->
  req.logout()
  res.redirect('/')

module.exports = app

