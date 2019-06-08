# React SPA with Express sessions and a WordPress backend
## Redis to make it fast and Puppeteer to make it search engine friendly

_work in progress_

"Forked" from https://github.com/mjstealey/wordpress-nginx-docker. Adapted to use Composer for WordPress management, and support deploying single page applications. Pretty much all of it is new, with the exception of documentation and Let's Encrypt config.

The setup allows for a monolithic approach, but it's recommended to make a separate repository for every service so you can have a sensible commit history. This should only wrap those services together.

The single page application is separated from WordPress entirely, and it runs at yourdomain.dev. WordPress runs at wp.yourdomain.dev, and the Express server runs at api.yourdomain.dev.

Using an Express server as the single page applications API server enables a zeroconf username-password authentication, that is free from the disadvantages of JWT, and doesn't require using nonces. Due to the nonce (CSRF) requirement and the data structure of the WordPress REST API, building single page applications is not optimal. The official recommendation is that you bake your SPA into a WordPress theme so you have access to wp_localize_script, and use it to get a nonce. The problem is that the nonce expires after a short amount of time of 12 hours, and to update it you either have to refresh the page or do hacky iframe stuff. You also get the overhead of loading WordPress, and your app isn't separated from it.

You should still use CSRF tokens, but you don't **have** to. Shoot yourself in the face if you want to. There's plenty of tutorials on how to setup csurf + express + react, so I suggest you do that before deploying to production. This will have that eventually, but I've some bills to pay and work to do.

In addition to handling authentication nicely for you, the Express server transforms API responses so that they're nicer to use 99% of the time. It makes the data more compact and replaces references to data by ID with the actual data when using the `?_embed` feature of the WordPress API.

On the WordPress side, there's a lot of WIP stuff that's pretty useful for building SPAs. The plugin k1-kit gives you a nice Transient api, URL resolve REST endpoint, and RestRoute class, which you can use to build your own API endpoints without unnecessary bloat, and even cache them. Add ACF Pro to the plugins and you're ready to build & use Gutenberg blocks *properly* in your frontend.

## Setup
`wordpress/` directory should contain a bedrock-style WordPress setup, one already exists for you, but you can migrate from an existing setup by just moving your composer.json and any custom plugins and themes to their respective folders.

Run `composer install` in the directory, and make changes to the config as you see fit in `config/` directory. Most is configured with .env later on.

`cra/` directory should contain a create-react-app like single page application. CRA is plug & play, you can init a new one in the directory. Any single page app should work, assuming there's a dist folder with an index.html.

Run `npm install && npm run build` in the directory. Setup .env if necessary.

`node/` directory should contain a NodeJS project. One already exists in the project directly because it powers the prerendering and the api proxy for the single page application.

Create the .env file using the sample as reference.

`certs/ certs-data/ letsencrypt/ logs/ nginx/` are covered in the documents located in the `docs/` folder. Haven't tested this in production yet, but they should at least serve as a base.

Configure `wordpress/ cra/ node/` directories first, and then create `.env` to the project root, replacing values from `.env_sample`. Just change the passwords ans salts if you're unsure about what to change.

After that, you only have to edit the nginx configuration to match your domain, and create entries to your computers hosts file. Editing the config is just a matter of search and replace, read the rest of the docs if you're unsure.

When everything is configured, run `docker-compose up`. Migrating an existing project is probably easiest if you start once with the default config, then replace the files and database with wp-cli.

## What doesn't work / exist yet
- Puppeteer
- Something fucky with redis sessions
- CSRF
- Production config

## FAQ

### How to run composer?
TL;DR: it doesn't matter. For local development, run it on your host machine to avoid permission errors.

### How to run wp-cli?
`docker-compose exec wpcli bash`, `cd wordpress`, and run any command you want.

### Can I edit the setup?
Yes. You probably have to. When you make changes to Dockerfile or docker-entrypoint.sh, rebuild with `docker-compose up --build`. Changes to other configuration files are applied on each `docker-compose up`, so restarting the container will do for other configuration files. You can also just `docker-compose exec nginx bash` to the container and reload the config manually

### I seem to have lost my plugins and themes
You probably broke the symlink, or Composer broke the symlink. wp-content/ directory is symlinked to wordpress/wp-content, and if that breaks, WordPress will have to use the defaults. Rebuilding the image is the easiest fix, but you can fix it manually.

```
$ docker-compose exec wordpress bash
rm -rf wordpress/wp-content; ln -sf $(pwd)/wp-content wordpress/wp-content;
```

That will delete the contents of wp-content in the directory nginx is serving. After that it will create a new symlink, and you should see everything again. As long as you never edit anything under wordpress/wordpress, you won't see any data loss.

### How do I develop plugins and themes on this?
If you're developing a plugin or theme that is only going to be used in this project, just add it to wp-content/plugins, and add it to the project with `git add -f`.

If your plugin already exists and has a git repository, the process is a bit different. Add it as a repository to composer.json
```
  "repositories": [
    // rest of the repos

    {
      "type": "vcs",
      "url": "git@github.com:k1sul1/k1-kit.git"
    }
  ]
```
and require it with `composer require author/plugin dev-master --prefer-source.

You can also just replace the composer package with your repository after composer install, but don't complain about permission issues or composer deleting your changes.

### I can't activate Redis Object Cache (the full plugin)
Me neither. I can't figure out why, but wp-includes/cache.php is getting loaded, and the cache functions are defined so that when the plugin tries to redefine them, a fatal error ensues.

The drop in seems to work.

### How do I disable Redis in WordPress?
Rename object-cache.php to disabled.object-cache.php

### How do I flush Redis in WordPress?
`wp cache flush`