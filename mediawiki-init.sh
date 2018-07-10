#!/bin/bash
echo "Database : $DATABASE_NAME"
DATABASE_FILE=/var/www/data/${DATABASE_NAME}.sqlite

DATA_DIR=/var/www/data
DATABASE_FILE=${DATA_DIR}/${DATABASE_NAME}.sqlite
LOG_DIR=${DATA_DIR}/log
CFG_DIR=${DATA_DIR}/config

function maintenance {
  #maintenance
  echo "Starting Mediawiki maintenance ..."
  maintenance/update.php --quick > ${LOG_DIR}/mw_update.log 

  #cd extensions/Wikibase/
  #php lib/maintenance/populateSitesTable.php >> ${LOG_DIR}/mw_update.log 
  #cd ../..
}

mkdir -p ${DATA_DIR}/images ${LOG_DIR} ${CFG_DIR}
chown www-data:www-data ${DATA_DIR}
chown www-data:www-data ${DATA_DIR}/images 
chown www-data:www-data ${LOG_DIR} ${CFG_DIR}


if [ -e ${CFG_DIR}/LocalSettings.custom.php ]
then
  #existant config is found, then no use the default it
  mv ./LocalSettings.custom.php ./LocalSettings.custom.origin.php
else
  #no config in volume, then initialize it
  mv ./LocalSettings.custom.php ${CFG_DIR}/LocalSettings.custom.php
fi
#finnaly create the symlink to the config in volume
ln -s ${CFG_DIR}/LocalSettings.custom.php ./LocalSettings.custom.php

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
  php maintenance/createAndPromote.php --bureaucrat --sysop --force Admin ${MEDIAWIKI_ADMIN_PASSWORD}
  
  maintenance
fi
