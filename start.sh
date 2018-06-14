#!/bin/sh
echo "Database : $DATABASE_NAME"
DATABASE_FILE=/var/www/data/${DATABASE_NAME}.sqlite

DATA_DIR=/var/www/data
DATABASE_FILE=${DATA_DIR}/${DATABASE_NAME}.sqlite
LOG_DIR=${DATA_DIR}/log
CFG_DIR=${DATA_DIR}/config

mkdir -p ${DATA_DIR}/images ${LOG_DIR} ${CFG_DIR}
chown www-data:www-data ${DATA_DIR}
chown www-data:www-data ${DATA_DIR}/images 
chown www-data:www-data ${LOG_DIR} ${CFG_DIR}

#if LocalSettings.custom.php is not a sym link,
# then move this file and create the link
if [ -f ./LocalSettings.custom.php ]
then
  mv ./LocalSettings.custom.php ${CFG_DIR}/LocalSettings.custom.php
  ln -s ${CFG_DIR}/LocalSettings.custom.php ./LocalSettings.custom.php
fi

#Fix latence problem
rm -rf ${DATA_DIR}/locks

#Init database
if [ -e ${DATABASE_FILE} ]
then 
  echo "Database already initialized" 
else 
  echo "Database not exist -> Initialize database" 
  #Copy the "empty" database
  cp /tmp/my_wiki.sqlite ${DATABASE_FILE}
  #Allow to write on database
  chmod 644 ${DATABASE_FILE} && chown www-data:www-data ${DATABASE_FILE}
  
  #change Admin password
  php maintenance/createAndPromote.php --bureaucrat --sysop --bot --force Admin ${MEDIAWIKI_ADMIN_PASSWORD}
  
  #maintenance
  cd maintenance 
  ./update.php --quick
  cd ..  
fi



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


