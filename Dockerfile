FROM php:7.4-fpm-alpine3.11 AS php_modules_stage
LABEL maintainer="pod@cro-co.co.jp"

ENV LANG="ja_JP.UTF-8" LANGUAGE="ja_JP:ja" LC_ALL="ja_JP.UTF-8"
ENV REDIS_VER="5.1.1"
ENV PHALCON_VER="4.0.2"

WORKDIR /tmp

RUN set -x \
    && apk update \
    && apk add tzdata && cat /usr/share/zoneinfo/Asia/Tokyo > /etc/localtime \
    && apk add curl git bash \
    && apk add autoconf m4 dpkg-dev dpkg file g++ gcc binutils libatomic libc-dev musl-dev make re2c git-perl perl-git perl-error perl libmagic mpc1 isl gmp \
    && apk add libwebp-dev jpeg-dev libpng-dev libxpm-dev freetype-dev bzip2-dev openldap-dev libzip-dev libxslt-dev gettext-dev libmcrypt-dev \
    && docker-php-ext-configure gd --with-webp --with-jpeg --with-xpm --with-freetype \
    && docker-php-source extract \
    && curl -L -o /tmp/redis.tar.gz https://codeload.github.com/phpredis/phpredis/tar.gz/${REDIS_VER} \
    && tar xfz /tmp/redis.tar.gz -C /tmp \
    && rm -r /tmp/redis.tar.gz \
    && mv /tmp/phpredis-${REDIS_VER} /usr/src/php/ext/redis \
    && docker-php-ext-install opcache bcmath pdo_mysql calendar exif sockets gd bz2 ldap zip xsl gettext redis \
    && yes '' | pecl install -f xdebug igbinary msgpack mcrypt apcu_bc apcu_bc \
    && docker-php-ext-enable xdebug igbinary msgpack mcrypt apc apcu \
    && mv /usr/local/etc/php/conf.d/docker-php-ext-apc.ini /usr/local/etc/php/conf.d/zz-docker-php-ext-apc.ini

RUN set -x \
    && curl -s https://codeload.github.com/phalcon/cphalcon/tar.gz/v${PHALCON_VER} -o - > cphalcon-${PHALCON_VER}.tar.gz \
    && tar xzf cphalcon-${PHALCON_VER}.tar.gz \
    && cd cphalcon-${PHALCON_VER}/build \
    && ./install \
    && docker-php-ext-enable phalcon

FROM php:7.4-cli-alpine3.11
ENV LANG="ja_JP.UTF-8" LANGUAGE="ja_JP:ja" LC_ALL="ja_JP.UTF-8"
COPY --from=php_modules_stage /usr/local/sbin/php-fpm /usr/local/sbin/php-fpm
COPY --from=php_modules_stage /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --from=php_modules_stage /usr/local/lib/php/extensions/no-debug-non-zts-20180731 /usr/local/lib/php/extensions/no-debug-non-zts-20180731
RUN set -x \
    && apk --no-cache add tzdata && cat /usr/share/zoneinfo/Asia/Tokyo > /etc/localtime \
    && apk --no-cache add libbz2 libldap libmcrypt libxslt libzip libstdc++ libxpm libpng libjpeg libwebp freetype libintl \
    && apk --no-cache add supervisor nginx bash \
    && rm -rf /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
