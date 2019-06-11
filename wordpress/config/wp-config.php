<?php
/**
 * This file contains WordPress config and replaces the usual wp-config.php
 */
$root_dir = dirname(__DIR__);
$webroot_dir = $root_dir . '/../wordpress';


/**
 * Expose global env() function from oscarotero/env
 */
Env::init();

$dotenv = new Dotenv\Dotenv($root_dir);
if (file_exists($root_dir . '/.env')) {
  $dotenv->load();
}

define('WP_ENV', strtolower(env('WP_ENV') ?? 'development'));

/**
 * Set URLs for WP
 * SERVER_NAME is used because WordPress uses it by default in some contexts and we
 * don't want to have million different variables to set.
 *
 * Deduct them from request parameters if developer didn't set the SERVER_NAME.
 *
 * We can always just use nginx to redirect aliases to canonical url
 * This helps changing between dev->stage->production
 */
if (env('WP_HOME') && env('WP_SITEURL')) {
  define('WP_HOME', env('WP_HOME'));
  define('WP_SITEURL', env('WP_SITEURL'));
}

/**
 * WordPress needs $_SERVER['HTTPS'] for is_ssl() in many places
 */
if (!isset($_SERVER['HTTPS'])) {
  $_SERVER['HTTPS'] = isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https' ? 'on' : 'off';
}

/**
 * Define connection details
 */

// define('WP_REDIS_USER', 'redis');
// define('WP_REDIS_PASSWORD', ''));
define('WP_REDIS_HOST', 'wpredis');
define('WP_REDIS_PORT', 6379);

define('DB_NAME', env('WORDPRESS_DB_NAME') ?? 'wordpress');
define('DB_USER', env('WORDPRESS_DB_USER') ?? 'root');
define('DB_PASSWORD', env('WORDPRESS_DB_PASSWORD') ?? 'password');

define('DB_HOST', env('WORDPRESS_DB_HOST') ?? 'mysql');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_swedish_ci');

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define('AUTH_KEY', env('WORDPRESS_AUTH_KEY') ?? '19bb286164893aa491a39f0b81805e8ed3827b06');
define('SECURE_AUTH_KEY', env('WORDPRESS_SECURE_AUTH_KEY') ?? 'd00aeffa41f2f2b82b6b9908a96ce52801512daa');
define('LOGGED_IN_KEY', env('WORDPRESS_LOGGED_IN_KEY') ?? '8e9511a0980b7870afa64980458fdb470a9ed8a9');
define('NONCE_KEY', env('WORDPRESS_NONCE_KEY') ?? '532dd1cd1afbef90e26c8b6a3c44357d04cd04b1');
define('AUTH_SALT', env('WORDPRESS_AUTH_SALT') ?? '53dffb7c6ca6c013f5d4cb3a51478fa19a9ce008');
define('SECURE_AUTH_SALT', env('WORDPRESS_SECURE_AUTH_SALT') ?? '2f6ab1237ac5168ebad9a3d4750f7df3fb2b2a2a');
define('LOGGED_IN_SALT', env('WORDPRESS_LOGGED_IN_SALT') ?? 'c6a5257e04cdb8ba31e91be5d26da744b20eab3e');
define('NONCE_SALT', env('WORDPRESS_NONCE_SALT') ?? '8299233dfb567465111be7944a423d28e103099c');

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'wp_';

switch (WP_ENV) {
  case 'production':
    // Configure Let's Encrypt and enable this.
    // define('FORCE_SSL_ADMIN', true);
    define('WP_DEBUG_DISPLAY', false);
    define('SCRIPT_DEBUG', false);
    define('WP_DEBUG', false);
  break;

  case 'development':
    define('SAVEQUERIES', true);
    define('WP_DEBUG', true);
    define('SCRIPT_DEBUG', true);
  break;

  default:
}
