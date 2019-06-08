const express = require('express')
const proxy = require('express-http-proxy')

/**
 * Sometimes JavaScript is a bit annoying.
 */
const isAFuckingObject = x => typeof x === 'object' && x !== null && !Array.isArray(x) && x

/**
 * AFAIK modified.content.protected is only true when the post is password protected.
 * Same for excerpts and titles. There's no password_protected field in the response,
 * but IMO you don't need it. If there's a password on the post, the content will be empty.
 * You can use that to display a password field, or if you really want to,
 * add that field to the API response with register_rest_field.
 *
 * You can also just disable this function if you'd rather have these parts unchanged.
 */
const flattenRendered = obj => {
  return !isAFuckingObject(obj) ? obj : Object.keys(obj).reduce((acc, k) => {
    acc[k] = obj[k] && obj[k].rendered ? obj[k].rendered : flattenRendered(obj[k])

    return acc
  }, {})
}

module.exports = function wp(postTypes, taxonomies) {
  const wpProxy = express.Router()
  const wpAdmin = express.Router()

  // This will be useful in the future.
  // const getTaxonomyFromRestBase = restBase => taxonomies[Object.keys(taxonomies).find(k => taxonomies[k].rest_base === restBase)]

  const transformContent = modified => {
    modified = flattenRendered(modified)

    if (modified.blocks) {
      modified.content = modified.blocks
      delete modified.blocks
    }

    modified.taxonomies = {}
    Object.keys(taxonomies).forEach(k => {
      const taxonomy = taxonomies[k]
      const { rest_base: restBase } = taxonomy

      if (modified[restBase]) {
        modified.taxonomies[restBase] = modified[restBase]
        delete modified[restBase]
      }
    })

    /**
     * I like ?_embed as a feature, but I dislike it's implementation. I don't want to map IDs to data in the frontend.
     * So let's remove _embedded from the response, and move it's data where it should be.
     */
    if (modified._embedded) {
      let { author: authors, 'wp:term': allTerms, replies } = modified._embedded

      // It's a weird structure. All terms are inside one object, but grouped in arrays, so that each array only contains terms
      // from the same taxonomy.
      allTerms.forEach(taxonomy => {
        if (!taxonomy.length) {
          // For some reason, WP adds an empty array to the wp:term array if there's no tags
          return;
        }

        taxonomy.forEach(term => {
          // const { id, rest_base: restBase, slug, taxonomy } = term
          // const taxonomy = getTaxonomyFromRestBase(restBase)
          const { taxonomy, id: termId } = term
          const { rest_base: restBase } = taxonomies[taxonomy]

          modified.taxonomies[restBase][modified.taxonomies[restBase].findIndex(id => id === termId)] = term
        })
      })

      /**
       * Post may be password protected, which results in this kind of object being present
       * {"code":"rest_cannot_read_post","message":"Sorry, you are not allowed to read the post for this comment.","data":{"status":401}}"
       * Filter that out.
       */
      replies = replies.filter(reply => reply.length)
      modified.replies = replies

      /**
       * Replace the author IDs with the full objects.
       * For some reason, the author field in _embedded is an array while *the* author field is an int.
       * Maybe it's possible to have multiple authors in the future, which is why you can change this behaviour
       * with en environment variable.
       */

      if (process.env.WP_SUPPORTS_MULTIPLE_AUTHORS) {
        authors.forEach(author => {
          modified.author[modified.author.findIndex(id => id === author.id)] = author
        })
      } else {
        modified.author = authors[0]
      }

      delete modified._embedded
    }

    return modified
  }

  wpAdmin.use('/*', (req, res) => {
    res.status(500).json({ error: "I'm sorry, even if I wanted to let you go here, WP wouldn't let you." })
  })

  wpAdmin.use('/admin-ajax.php', (req, res, next) => {
    next()
  })

  wpProxy.use('/wp-admin', wpAdmin)

  wpProxy.use('/wp-includes', (req, res) => {
    res.status(500).json({ error: "I'm don't think that there's anything here that you could use." })
  })

  wpProxy.get('/about', function (req, res) {
    res.json({ message: '/wp/ is a proxy for WordPress REST API. Use the WordPress REST API handbook if lost. It makes "minor" modifications to data.' })
  })

  /**
   * Proxy requests to WordPress. Handles authentication using basic auth.
   * This makes basic auth usable in the context of a SPA,
   * as storing the username and password in the client isn't necessary.
   */
  wpProxy.use(
    '/',
    (req, res, next) => {
      if (req.session.apiAuthHeader) {
        req.headers['Authorization'] = req.session.apiAuthHeader
      }

      next()
    },
    proxy('http://nginx/', {
      /**
       * Transform responses from WordPress. HTML is probably the worst possible format
       * for a SPA, so it's replaced with block data when available.
       */
      userResDecorator(proxyRes, proxyResData, userReq, userRes) {
        const data = proxyResData.toString('utf8').trim()
        const isLikelyXML = data.indexOf('<') === 0
        const isLikelyJSON = !isLikelyXML && (data.indexOf('{') === 0 || data.indexOf('[') === 0)

        if (isLikelyJSON) {
          let json = JSON.parse(data)

          if (Array.isArray(json)) {
            json = json.map(transformContent)
          } else {
            json = transformContent(json)
          }

          return json
        }

        return proxyResData
      }
    })
  )

  return wpProxy
}
