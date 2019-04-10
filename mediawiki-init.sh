#!/bin/bash
echo "Database : $DATABASE_NAME ($DATABASE_TYPE)"

DATA_DIR=/var/www/data
DATABASE_FILE=${DATA_DIR}/${DATABASE_NAME}.sqlite
MYSQL_IMPORT_FILE=${DATA_DIR}/import.sql
LOG_DIR=${DATA_DIR}/log
CFG_DIR=${DATA_DIR}/config
IMG_DIR=${DATA_DIR}/images 
MYSQL_DATA=${DATA_DIR}/mysql

{ \
  echo "# Database" ; \
  echo "\$wgDBtype        = \"$DATABASE_TYPE\";" ; \
  echo "\$wgDBname        = \"$DATABASE_NAME\";" ; \
  echo "\$wgDBserver      = \"localhost\";" ; \
  echo "\$wgDBuser        = \"$DATABASE_NAME\";" ; \
  echo "\$wgDBpassword    = \"$DATABASE_NAME\";" ; \
  echo "\$wgSQLiteDataDir = \"$DATA_DIR\";" ; \
} >> ./LocalSettings.php

# Configure Mysql data dir
sed -i "/datadir/ s|/var/lib/mysql|$DATA_DIR/mysql|" /etc/mysql/mariadb.conf.d/50-server.cnf

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

if [ -e "${DATABASE_FILE}" ] && [ $MYSQL_INIT ]
then
  echo "Initialize a Mysql database"
  
  if [ ! -d "$MYSQL_DATA" ] 
  then
    mkdir $MYSQL_DATA
    chmod +x $DATA_DIR
    cp -a /var/lib/mysql $DATA_DIR/ 
  fi
  
  service mysql start
  echo "CREATE DATABASE IF NOT EXISTS $DATABASE_NAME;" | mysql
  if [ -e "${MYSQL_IMPORT_FILE}" ]
  then
    echo "Init MySQL database"
    # initialize mysql database from an owned file
    mysql ${DATABASE_NAME} < $MYSQL_IMPORT_FILE
  fi
  # import data from SQLite database
  echo "Export data from SQLite database"
  sqlite3 ${DATABASE_FILE} .dump > dump.sql
  echo "Genereate dump for MySQL"
  echo "SET FOREIGN_KEY_CHECKS=0;" > out.sql
  dump_for_mysql.py < dump.sql >> out.sql
  echo "SET FOREIGN_KEY_CHECKS=1;" >> out.sql
  echo "CREATE USER '${DATABASE_NAME}'@'localhost' IDENTIFIED BY '${DATABASE_NAME}';" >> out.sql
  echo "GRANT ALL PRIVILEGES ON ${DATABASE_NAME}.* TO '${DATABASE_NAME}'@'localhost';" >> out.sql
  echo "Import data in MySQL database"
  mysql -f ${DATABASE_NAME} < out.sql
  #rm -rf dump.sql out.sql
  service mysql stop
elif [ "$DATABASE_TYPE" = "mysql" ]
then
  echo "Use a Mysql database"
elif [ -e ${DATABASE_FILE} ] && [ ! $VOLUME_UPDATE ]
then 
  echo "SQLite Database already initialized" 
elif [ ! -z $VOLUME_TAR_URL ]
then
  echo "SQLite Database initialized in tar -> download it" 
  curl -fSL $VOLUME_TAR_URL | tar -xz -C $DATA_DIR
  ln -s ${DATA_DIR} data
  ln -s ${DATA_DIR}/download ../download
else
  echo "Initialize an empty SQLite database" 
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

