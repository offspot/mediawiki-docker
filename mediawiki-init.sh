#!/bin/bash
echo "Database : $DATABASE_NAME ($DATABASE_TYPE)"

DATA_DIR=/var/www/data
DATABASE_FILE=${DATA_DIR}/${DATABASE_NAME}.sqlite
MYSQL_IMPORT_FILE=${DATA_DIR}/import.sql
LOG_DIR=${DATA_DIR}/log
CFG_DIR=${DATA_DIR}/config
IMG_DIR=${DATA_DIR}/images
DATA_SITE_ROOT_DIR=${DATA_DIR}/site_root
MYSQL_DATA=${DATA_DIR}/mysql

if [ -z "$URL" ] ; then
  WGSERVER="WebRequest::detectServer();"
  WGCANONICALSERVER="http://localhost"
else
  WGSERVER="\"$URL\";"
  WGCANONICALSERVER=$WGSERVER
fi
echo "Serving for: $WGSERVER / $WGCANONICALSERVER"

{ \
  echo "# Database" ; \
  echo "\$wgDBtype        = \"$DATABASE_TYPE\";" ; \
  echo "\$wgDBname        = \"$DATABASE_NAME\";" ; \
  echo "\$wgDBserver      = \"localhost\";" ; \
  echo "\$wgDBuser        = \"$DATABASE_NAME\";" ; \
  echo "\$wgDBpassword    = \"$DATABASE_NAME\";" ; \
  echo "\$wgSQLiteDataDir = \"$DATA_DIR\";" ; \
  echo "\$wgServer        = $WGSERVER";
  echo "\$wgCanonicalServer= $WGSERVER";
  # echo "\$wgShowExceptionDetails = true;";
} >> ./LocalSettings.php

if [ "$DATABASE_TYPE" = "sqlite" ]
then
  # Configure SQLite maintenance weekly
  { \
    echo "#!/bin/sh" ; \
    echo "cd ${WIKI_DIR}" ; \
    echo "php maintenance/sqlite.php --vacuum >> ${DATA_DIR}/log/mw_update.log 2>&1" ; \
  } > /etc/cron.weekly/wm_maintenance && chmod 0500 /etc/cron.weekly/wm_maintenance
fi

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

if [ "$DATABASE_TYPE" = "mysql" ]
then
  echo "Use a Mysql database"
  # Configure Mysql data dir
  sed -i "/datadir/ s|/var/lib/mysql|$DATA_DIR/mysql|" /etc/mysql/mariadb.conf.d/50-server.cnf
  chmod +x $DATA_DIR

  if [ $MYSQL_INIT ]
  then
    echo "Initialize a Mysql database"

    if [ ! -d "$MYSQL_DATA" ]
    then
      #Create and init directory if no exist
      mkdir $MYSQL_DATA
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

    #set privileges
    echo "CREATE USER '${DATABASE_NAME}'@'localhost' IDENTIFIED BY '${DATABASE_NAME}';" | mysql -f
    echo "GRANT ALL PRIVILEGES ON ${DATABASE_NAME}.* TO '${DATABASE_NAME}'@'localhost';" | mysql -f
    echo "FLUSH PRIVILEGES" | mysql -f

    if [ -e "${DATABASE_FILE}" ]
    then
      # import data from SQLite database
      echo "Export data from SQLite database"
      sqlite3 ${DATABASE_FILE} .dump > dump.sql
      echo "Genereate dump for MySQL"
      echo "SET FOREIGN_KEY_CHECKS=0;" > out.sql
      dump_for_mysql.py < dump.sql >> out.sql
      echo "SET FOREIGN_KEY_CHECKS=1;" >> out.sql
      echo "Import data in MySQL database"
      mysql -f ${DATABASE_NAME} < out.sql
      rm -rf dump.sql out.sql
    fi

    # remove settings to launch install script to populate a default database
    mv ./LocalSettings.php ./LocalSettings.php.tmp
    php maintenance/install.php --dbuser $DATABASE_NAME --dbpass $DATABASE_NAME --dbname $DATABASE_NAME --pass MEDIAWIKI_ADMIN_PASSWORD $DATABASE_NAME Admin
    mv ./LocalSettings.php.tmp ./LocalSettings.php

    # skip rest of mediawiki init.
    echo "MYSQL INIT COMPLETE. Please stop container, remove 'MYSQL_INIT=1' env and restart."
    exit 1
  else
    service mysql start
  fi

  # Adding mysqldump to crontab
  { \
    echo "#!/bin/sh" ; \
    echo "mysqldump --databases ${DATABASE_NAME} > ${DATA_DIR}/${DATABASE_NAME}.sql" ; \
  } > /etc/cron.weekly/MySQLDump && chmod 0500 /etc/cron.weekly/MySQLDump

  echo "* *  * * *  root  /usr/bin/flock -w 0 /dev/shm/cron.lock php ${WIKI_DIR}/maintenance/runJobs.php" > /etc/cron.d/runJobs
fi

if [ ! -z $VOLUME_TAR_URL ]
then
  echo "Initialize data dir with a tar -> download it"
  curl -fSL $VOLUME_TAR_URL | tar -xz -C $DATA_DIR
  ln -s ${DATA_DIR} data
  ln -s ${DATA_DIR}/download ../download
fi

if [ "$DATABASE_TYPE" = "sqlite" ]
then
  if [ -e ${DATABASE_FILE} ]
  then
    echo "SQLite Database already initialized"
  else
    echo "Initialize an empty SQLite database"
    #Copy the "empty" database
    cp /tmp/my_wiki.sqlite ${DATABASE_FILE}
  fi
fi

# Allow to custom a few content at site root
if [ -d ${DATA_SITE_ROOT_DIR} ]
then
    for FILE in $(find ${DATA_SITE_ROOT_DIR} -type f)
    do
        FILE=$(readlink -f ${FILE})
        rm -f ../$(basename ${FILE})
        ln -s ${FILE} ../
    done
else
    mkdir ${DATA_SITE_ROOT_DIR}
fi

# Set the secret token to download datadir
sed -i s/?ACCESS_TOKEN?/$EXPORT_TOKEN/g ../export_data.php

# Fix latence problem
rm -rf ${DATA_DIR}/locks

# Allow to write on database
chmod 644 ${DATABASE_FILE} && chown www-data:www-data ${DATABASE_FILE}

echo "Starting Mediawiki maintenance ..."
maintenance/update.php --quick > ${LOG_DIR}/mw_update.log

#change Admin password
php maintenance/createAndPromote.php --bureaucrat --sysop --force Admin ${MEDIAWIKI_ADMIN_PASSWORD}
