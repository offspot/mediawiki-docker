#!/bin/sh

echo "Starting Parsoid ..."
cd parsoid
node bin/server.js &
cd .. 

service memcached start 
service php7.0-fpm start
service cron start

if [ "$DATABASE_TYPE" = "mysql" ]
then
  service mysql start
fi

#service nginx start
#/bin/bash

echo "Starting Nginx and wait ..."
nginx -g "daemon off;"
