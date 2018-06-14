#!/bin/sh

echo "Starting Persoid ..."
cd parsoid
node bin/server.js &
cd .. 

service memcached start 
service php7.0-fpm start

#service nginx start
#/bin/bash

echo "Starting Nginx and wait ..."
nginx -g "daemon off;"