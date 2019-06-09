#!/bin/bash
set -euo pipefail


if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
	if [ "$(id -u)" = '0' ]; then
		case "$1" in
			apache2*)
				user="${APACHE_RUN_USER:-www-data}"
				group="${APACHE_RUN_GROUP:-www-data}"

				# strip off any '#' symbol ('#1000' is valid syntax for Apache)
				pound='#'
				user="${user#$pound}"
				group="${group#$pound}"
				;;
			*) # php-fpm
				user='www-data'
				group='www-data'
				;;
		esac
	else
		user="$(id -u)"
		group="$(id -g)"
	fi

  # Have more folders which PHP needs write access to? Add them here
  [ -d "wp-content/uploads" ] && chown -R "$user:$group" wp-content/uploads
  [ -d "wp-content/plugins/k1-spa/acf-json" ] && chown -R "$user:$group" wp-content/plugins/k1-spa/acf-json
fi;

rm -rf /var/www/wp/wordpress/wp-content
ln -sf /var/www/wp/wp-content/ /var/www/wp/wordpress/wp-content

exec "$@"
