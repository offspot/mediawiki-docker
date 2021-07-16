#!/bin/sh

service memcached start 

mediawiki-init.sh

service php7.3-fpm start
service cron start

if [ "$DATABASE_TYPE" = "mysql" ]
then
  service mysql start
fi

echo "Starting Nginx and wait ..."
nginx -g "daemon off;"
