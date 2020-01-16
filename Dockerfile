FROM php:7.3-fpm-alpine3.10 AS php_modules_stage
LABEL maintainer="pod@cro-co.co.jp"

ENV LANG="ja_JP.UTF-8" LANGUAGE="ja_JP:ja" LC_ALL="ja_JP.UTF-8"

WORKDIR /tmp

RUN set -x \
    && apk update \
    && apk add tzdata && cat /usr/share/zoneinfo/Asia/Tokyo > /etc/localtime \
    && apk add curl git bash \
    && apk add autoconf m4 dpkg-dev dpkg file g++ gcc binutils libatomic libc-dev musl-dev make re2c git-perl perl-git perl-error perl libmagic mpc1 mpfr3 isl gmp \
    && apk add libwebp-dev jpeg-dev libpng-dev libxpm-dev freetype-dev bzip2-dev openldap-dev libzip-dev libxslt-dev gettext-dev libmcrypt-dev \
    && docker-php-ext-configure gd --with-webp-dir=/usr/include --with-jpeg-dir=/usr/include --with-xpm-dir=/usr/include --with-freetype-dir=/usr/include --with-png-dir=/usr/include \
    && docker-php-ext-install opcache bcmath pdo_mysql calendar exif sockets gd bz2 ldap zip xsl gettext \
    && yes '' | pecl install -f xdebug igbinary msgpack mcrypt apcu_bc apcu_bc \
    && docker-php-ext-enable xdebug igbinary msgpack mcrypt apc apcu \
    && mv /usr/local/etc/php/conf.d/docker-php-ext-apc.ini /usr/local/etc/php/conf.d/zz-docker-php-ext-apc.ini

RUN set -x \
    && curl -s https://codeload.github.com/phalcon/cphalcon/tar.gz/v3.4.5 -o - > cphalcon-3.4.5.tar.gz \
    && tar xzf cphalcon-3.4.5.tar.gz \
    && cd cphalcon-3.4.5/build \
    && ./install \
    && docker-php-ext-enable phalcon

RUN set -x \
    && cd /tmp \
    && git clone https://github.com/awslabs/aws-elasticache-cluster-client-libmemcached.git \
    && cd aws-elasticache-cluster-client-libmemcached \
    && touch configure.ac aclocal.m4 configure Makefile.am Makefile.in \
    && sed -i "s#static char \*\*environ= NULL;#char **environ= NULL;#" libtest/cmdline.cc \
    && mkdir BUILD \
    && cd BUILD \
    && ../configure --prefix=/tmp/libmemcached --with-pic --disable-sasl \
    && mkdir /tmp/libmemcached \
    && make \
    && make install \
    && cd /tmp \
    && git clone https://github.com/awslabs/aws-elasticache-cluster-client-memcached-for-php.git \
    && cd aws-elasticache-cluster-client-memcached-for-php \
    && git checkout php7 \
    && phpize \
    && ./configure --with-libmemcached-dir=/tmp/libmemcached --enable-memcached-igbinary --enable-memcached-json --enable-memcached-msgpack --disable-memcached-sasl \
    && sed -i "s#-lmemcached#/tmp/libmemcached/lib/libmemcached.a#" Makefile \
    && sed -i "s#-lmemcachedutil#/tmp/libmemcached/lib/libmemcachedutil.a -lcrypt -lpthread -lm -lstdc++#" Makefile \
    && make \
    && make install \
    && docker-php-ext-enable memcached \
    && mv /usr/local/etc/php/conf.d/docker-php-ext-memcached.ini /usr/local/etc/php/conf.d/zz-docker-php-ext-memcached.ini

FROM php:7.3-cli-alpine3.10
ENV LANG="ja_JP.UTF-8" LANGUAGE="ja_JP:ja" LC_ALL="ja_JP.UTF-8"
COPY --from=php_modules_stage /usr/local/sbin/php-fpm /usr/local/sbin/php-fpm
COPY --from=php_modules_stage /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --from=php_modules_stage /usr/local/lib/php/extensions/no-debug-non-zts-20180731 /usr/local/lib/php/extensions/no-debug-non-zts-20180731
RUN set -x \
    && apk --no-cache add tzdata && cat /usr/share/zoneinfo/Asia/Tokyo > /etc/localtime \
    && apk --no-cache add libbz2 libldap libmcrypt libxslt libzip libstdc++ libxpm libpng libjpeg libwebp freetype libintl \
    && apk --no-cache add supervisor nginx bash \
    && rm -rf /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
