require('dotenv').config()
const express = require('express')
const cors = require('cors')
const bodyParser = require('body-parser')
const session = require('express-session')
const redis = require('redis').createClient({ prefix: 'node_', host: 'noderedis' })
const RedisStore = require('connect-redis')(session)
const axios = require('axios')
const listEndpoints = require('express-list-endpoints')
const wp = require('./api/wp.js')
const btoa = require('./lib/btoa')


async function main() {
  let taxonomies, postTypes
  const { WP_USER, WP_PASSWORD } = process.env

  if (!WP_USER || !WP_PASSWORD) {
    console.error('Missing configuration details, did you create the .env file to server root?')
    process.exit(1)
  }

  try {
    const Authorization = `Basic ${btoa(`${WP_USER}:${WP_PASSWORD}`)}`
    const taxonomiesReq = await axios.get('http://nginx/wp-json/wp/v2/taxonomies', { headers: { Authorization } })
    const postTypesReq = await axios.get('http://nginx/wp-json/wp/v2/types', { headers: { Authorization } })

    taxonomies = taxonomiesReq.data
    postTypes = postTypesReq.data
  } catch (e) {
    console.error(e)
    console.log("Failed to get WordPress data. Server can't start. Retrying in 10 seconds...")
    console.log(`Does username ${WP_USER} exist in WordPress?`)

    return setTimeout(main, 10000)
  }

  const app = express()
  const port = 3000

  const whitelist = ['http://kisu.local', 'http://kisu.local:3000']
  const corsOptions = {
    origin (origin, callback) {
      if (!origin || whitelist.indexOf(origin) !== -1) {
        callback(null, true)
      } else {
        callback(new Error(`CORS: Origin ${origin} is not allowed to access`))
      }
    },
    credentials: true,
  }

  redis.on('connect', function() {
      console.log('Redis client connected');
  });

  redis.on("error", function (err) {
      console.error(err);
  });

  // TODO: CSRF here

  app.set('trust proxy', 1)
  app.use(cors(corsOptions))
  app.use(bodyParser.json())
  app.use(session({
    // This "works", except that it seems to fail to save session data
    // store: new RedisStore({
      // client: redis,
    // }),
    secret: process.env.SESSION_SECRET || 'keyboard cat',
    resave: false,
    cookie: {
      domain: process.env.SESSION_COOKIE_DOMAIN,
      secure: false,
      expires: 99999999999999999999999999999999999999999999, // How about never.
    }
  }))

  app.get('/', function (req, res) {
    res.json(listEndpoints(app))
  })

  app.post('/login', async function (req, res) {
    const { username, password } = req.body
    const authHeader = `Basic ${btoa(`${username}:${password}`)}`

    try {
      const { data } = await axios.get('http://nginx/wp-json/wp/v2/users/me', {
        headers: {
          Authorization: authHeader
        }
      })

      req.session.wpUser = data.id
      req.session.apiAuthHeader = authHeader

      req.session.save()
      res.json({ success: 'Logged in succesfully!' })
    } catch (e) {
      // Technically there's about 500 other reasons that this can go wrong
      // but let's assume that the server is always available
      res.status(401).json({ error: 'Wrong username or password!' })
    }
  })

  app.post('/logout', async (req, res) => {
    if (req.session) {
      req.session.destroy(e => {
        if (!e) {
          return res.json({ success: 'Logged out!' })
        }

        console.error(e)
        res.status(500).json({ error: 'Something terrible happened, and your logout failed!' })
      })
    }

    res.status(418).json({ error: 'Why would you log out when you haven\'t even logged in?' })
  })

  app.use('/wp', wp(postTypes, taxonomies))

  app.use(function (err, req, res, next) {
    console.error(err.stack)

    if (err.message.indexOf('Unexpected token < in JSON') > -1) {
      return res.status(500).json({ error: err.message })
    }

    res.status(500).send({ error: 'Something broke!' })
  })

  app.listen(port, () => console.log(`Node listening in port ${port}!`))
}

main()
