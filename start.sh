#!/bin/sh

handle-htpassword-opt.sh
service memcached start && \
mediawiki-init.sh && \
service php8.4-fpm start && \
service cron start

echo "Starting…"
exec "$@"
