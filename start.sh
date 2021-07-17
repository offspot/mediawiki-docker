#!/bin/sh

service memcached start && \
mediawiki-init.sh && \
service php7.3-fpm start && \
service cron start

echo "Starting…"
exec "$@"
