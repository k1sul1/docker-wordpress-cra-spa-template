# Shamelessly copied from wordpress:5.2.1-php7.3-fpm
# I don't want WordPress, I just want the php-fpm because setting it up sucks

FROM php:7.3-fpm

# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
# and other things
RUN set -ex; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libjpeg-dev \
		libmagickwand-dev \
		libpng-dev \
		libzip-dev \
	; \
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-install \
		bcmath \
		exif \
		gd \
		mysqli \
		zip \
		calendar \
		mbstring \
		shmop \
		# phar \ # Why does this cause an error?
	; \
	pecl install imagick-3.4.4; \
	docker-php-ext-enable imagick; \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*;

# Install some utils
RUN set -ex; \
  apt-get update; \
  # We just nuked the list so it's necessary to fetch it again
  apt-get install -y \
    wget \
    nano \
    vim \
    less \
    unzip \
    zip \
    git \
    inetutils-ping; \
    wget https://raw.githubusercontent.com/composer/getcomposer.org/76a7060ccb93902cd7576b67264ad91c8a2700e2/web/installer -O - -q | php -- --quiet; \
    # wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \ # wp-cli isn't needed on this image right now
    chmod +x composer.phar; \
    # chmod +x wp-cli.phar; \
    mv composer.phar /usr/bin/composer; \
    # mv wp-cli.phar /usr/bin/wp; \
    echo "Almost done!"


# Redis has to downloaded too
RUN pecl install -o -f redis \
&&  rm -rf /tmp/pear \
&&  docker-php-ext-enable redis


# set recommended PHP.ini settings
# https://codex.wordpress.org/Editing_wp-config.php#Configure_Error_Logging
RUN { \
		echo 'error_reporting = 4339'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
    echo 'suhosin.executor.include.whitelist="phar"'; \
	} > /usr/local/etc/php/conf.d/error-logging.ini

RUN echo "\n\
upload_max_filesize = 100M \n\
post_max_size = 100M \n\
memory_limit = 200M \n\
max_execution_time = 60 \n\
max_input_time = 60 \n\
user_ini.cache_ttl = 30 \n\
opcache.enable_cli = 1 \n\
opcache.validate_timestamps = 1 \n\
opcache.revalidate_freq = 0 \n\
opcache.fast_shutdown = 0 \n\
" > /usr/local/etc/php/conf.d/settings.ini

VOLUME /var/www/wp

ADD ./wordpress /var/www/wp
WORKDIR /var/www/wp

RUN composer global require hirak/prestissimo;
RUN set -ex; \
  # composer install; \ # Running this here will fuck up permissions.
  rm -rf wordpress/wp-content; ln -sf $(pwd)/wp-content wordpress/wp-content;

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
