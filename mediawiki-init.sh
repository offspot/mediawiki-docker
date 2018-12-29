#!/bin/bash
echo "Database : $DATABASE_NAME"

DATA_DIR=/var/www/data
DATABASE_FILE=${DATA_DIR}/${DATABASE_NAME}.sqlite
LOG_DIR=${DATA_DIR}/log
CFG_DIR=${DATA_DIR}/config
IMG_DIR=${DATA_DIR}/images 

mkdir -p ${IMG_DIR} ${LOG_DIR} ${CFG_DIR}
chown www-data:www-data ${DATA_DIR} ${IMG_DIR} ${LOG_DIR} ${CFG_DIR}

if [ -e ${CFG_DIR}/LocalSettings.custom.php ]
then
  #existant config is found, then no use the default it
  mv ./LocalSettings.custom.php ./LocalSettings.custom.origin.php
else
  #no config in volume, then initialize it
  mv ./LocalSettings.custom.php ${CFG_DIR}/LocalSettings.custom.php
fi
ln -s ${CFG_DIR}/LocalSettings.custom.php ./LocalSettings.custom.php

if [ -e ${DATABASE_FILE} ] && [ ! $VOLUME_UPDATE ]
then 
  echo "Database already initialized" 
elif [ ! -z $VOLUME_TAR_URL ]
then
  echo "Database initialized in tar -> download it" 
  curl -fSL $VOLUME_TAR_URL | tar -xz -C $DATA_DIR
  ln -s ${DATA_DIR} data
  ln -s ${DATA_DIR}/download ../download
else
  echo "Initialize an empty database" 
  #Copy the "empty" database
  cp /tmp/my_wiki.sqlite ${DATABASE_FILE}
  #change Admin password
  php maintenance/createAndPromote.php --bureaucrat --sysop --force Admin ${MEDIAWIKI_ADMIN_PASSWORD}
fi

ln -s ${DATA_DIR}/images/logo.png ../logo.png
if [ -e ${DATA_DIR}/images/favicon.ico ]
then
  rm -f ../favicon.ico
  ln -s ${DATA_DIR}/images/favicon.ico ../favicon.ico
fi

#Fix latence problem
rm -rf ${DATA_DIR}/locks

#Allow to write on database
chmod 644 ${DATABASE_FILE} && chown www-data:www-data ${DATABASE_FILE}

echo "Starting Mediawiki maintenance ..."
maintenance/update.php --quick > ${LOG_DIR}/mw_update.log 

