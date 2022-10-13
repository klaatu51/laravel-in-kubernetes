ARG PHP_EXTS="bcmath ctype fileinfo mbstring pdo pdo_mysql dom pcntl"
ARG PHP_PECL_EXTS="redis"

#
# composer-base
#

FROM composer:2.1 as composer_base

ARG PHP_EXTS
ARG PHP_PECL_EXTS

RUN mkdir -p /opt/apps/laravel-in-kubernetes /opt/apps/laravel-in-kubernetes/bin

# Next, set our working directory
WORKDIR /opt/apps/laravel-in-kubernetes

RUN addgroup -S composer \
    && adduser -S composer -G composer \
    && chown -R composer /opt/apps/laravel-in-kubernetes \
    && apk add --virtual build-dependencies --no-cache ${PHPIZE_DEPS} openssl ca-certificates libxml2-dev oniguruma-dev \
    && docker-php-ext-install -j$(nproc) ${PHP_EXTS} \
    && pecl install ${PHP_PECL_EXTS} \
    && docker-php-ext-enable ${PHP_PECL_EXTS} \
    && apk del build-dependencies

USER composer

COPY --chown=composer composer.json composer.lock ./

RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

COPY --chown=composer . .

RUN composer install --no-dev --prefer-dist

#
# frontend
#

FROM node:14 as frontend

COPY --from=composer_base /opt/apps/laravel-in-kubernetes /opt/apps/laravel-in-kubernetes

WORKDIR /opt/apps/laravel-in-kubernetes

RUN npm install && \
    npm run build

#
# cli
#

FROM php:8.0-alpine as cli

ARG PHP_EXTS
ARG PHP_PECL_EXTS

WORKDIR /opt/apps/laravel-in-kubernetes

RUN apk add --virtual build-dependencies --no-cache ${PHPIZE_DEPS} openssl ca-certificates libxml2-dev oniguruma-dev && \
    docker-php-ext-install -j$(nproc) ${PHP_EXTS} && \
    pecl install ${PHP_PECL_EXTS} && \
    docker-php-ext-enable ${PHP_PECL_EXTS} && \
    apk del build-dependencies

COPY --from=composer_base /opt/apps/laravel-in-kubernetes /opt/apps/laravel-in-kubernetes
COPY --from=frontend /opt/apps/laravel-in-kubernetes/public /opt/apps/laravel-in-kubernetes/public

#
# fpm_server
#

FROM php:8.1-fpm-alpine as fpm_server

ARG PHP_EXTS
ARG PHP_PECL_EXTS

WORKDIR /opt/apps/laravel-in-kubernetes

RUN apk add --virtual build-dependencies --no-cache ${PHPIZE_DEPS} openssl ca-certificates libxml2-dev oniguruma-dev && \
    docker-php-ext-install -j$(nproc) ${PHP_EXTS} && \
    pecl install ${PHP_PECL_EXTS} && \
    docker-php-ext-enable ${PHP_PECL_EXTS} && \
    apk del build-dependencies

USER  www-data

COPY --from=composer_base --chown=www-data /opt/apps/laravel-in-kubernetes /opt/apps/laravel-in-kubernetes
COPY --from=frontend --chown=www-data /opt/apps/laravel-in-kubernetes/public /opt/apps/laravel-in-kubernetes/public

RUN php artisan event:cache && \
    php artisan route:cache && \
    php artisan view:cache

#
# webserver
#

FROM nginx:1.20-alpine as web_server

WORKDIR /opt/apps/laravel-in-kubernetes

COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template

COPY --from=frontend /opt/apps/laravel-in-kubernetes/public /opt/apps/laravel-in-kubernetes/public

#
# cron
#

FROM cli as cron

WORKDIR /opt/apps/laravel-in-kubernetes

RUN touch laravel.cron && \
    echo "* * * * * cd /opt/apps/laravel-in-kubernetes && php artisan schedule:run" >> laravel.cron && \
    crontab laravel.cron

CMD ["crond", "-l", "2", "-f"]