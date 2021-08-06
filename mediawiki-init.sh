#!/bin/bash
echo "Mediawiki initialization script for database : $DATABASE_NAME ($DATABASE_TYPE)"

DATA_DIR=/var/www/data
DATABASE_FILE=${DATA_DIR}/${DATABASE_NAME}.sqlite
MYSQL_IMPORT_FILE=${DATA_DIR}/import.sql
LOG_DIR=${DATA_DIR}/log
CFG_DIR=${DATA_DIR}/config
IMG_DIR=${DATA_DIR}/images
DATA_SITE_ROOT_DIR=${DATA_DIR}/site_root
MYSQL_DATA=${DATA_DIR}/mysql
WG_CACHE_DIR=/dev/shm/mw

if [ -z "$URL" ] ; then
  WGSERVER="WebRequest::detectServer();"
  WGCANONICALSERVER="http://localhost"
else
  WGSERVER="\"$URL\";"
  WGCANONICALSERVER=$WGSERVER
fi

echo "   Reachable from: $WGSERVER / $WGCANONICALSERVER"

echo "> Writting Settings."

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
  echo "> Adding SQLite maintenance script to weekly cron"
  { \
    echo "#!/bin/sh" ; \
    echo "cd ${WIKI_DIR}" ; \
    echo "php maintenance/sqlite.php --vacuum >> ${DATA_DIR}/log/mw_update.log 2>&1" ; \
  } > /etc/cron.weekly/wm_maintenance && chmod 0500 /etc/cron.weekly/wm_maintenance
fi

echo "> Ensuring proper folder structure and permissions"
mkdir -p ${IMG_DIR} ${LOG_DIR} ${CFG_DIR}
chown www-data:www-data ${DATA_DIR} ${IMG_DIR} ${LOG_DIR} ${CFG_DIR}
mkdir -p $WG_CACHE_DIR && chown www-data:www-data -R $WG_CACHE_DIR

echo "> Adding custom settings file (if any)"
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
  echo "> Setting mysql datadir to $MYSQL_DATA"

  # Configure Mysql data dir
  sed -i "/datadir/ s|/var/lib/mysql|$MYSQL_DATA|" /etc/mysql/mariadb.conf.d/50-server.cnf
  chmod +x $DATA_DIR

  if [ $MYSQL_INIT ]
  then
    echo "> Setting up mysql database (MYSQL_INIT is set)"

    if [ ! -d "$MYSQL_DATA" ]
    then
      echo "  > Creating mysql datadir"
      #Create and init directory if no exist
      mkdir $MYSQL_DATA
      cp -a /var/lib/mysql $DATA_DIR/
    fi

    echo "  > Starting MySQL"
    service mysql start

    echo "  > Creating* database $DATABASE_NAME"
    echo "CREATE DATABASE IF NOT EXISTS $DATABASE_NAME;" | mysql

    if [ -e "${MYSQL_IMPORT_FILE}" ]
    then
      # initialize mysql database from an owned file
      echo "  > Importing import.sql into $DATABASE_NAME"
      mysql ${DATABASE_NAME} < $MYSQL_IMPORT_FILE
    fi

    #set privileges
    echo "  > Creating user $DATABASE_NAME with appropriate privileges"
    echo "CREATE USER '${DATABASE_NAME}'@'localhost' IDENTIFIED BY '${DATABASE_NAME}';" | mysql -f
    echo "GRANT ALL PRIVILEGES ON ${DATABASE_NAME}.* TO '${DATABASE_NAME}'@'localhost';" | mysql -f
    echo "FLUSH PRIVILEGES" | mysql -f

    if [ -e "${DATABASE_FILE}" ]
    then
      # import data from SQLite database
      echo "  > Importing from SQLite file $DATABASE_FILE into $DATABASE_NAME"
      echo "    > exporting to dump.sql"
      sqlite3 ${DATABASE_FILE} .dump > dump.sql
      echo "    > transforming to out.sql"
      echo "SET FOREIGN_KEY_CHECKS=0;" > out.sql
      dump_for_mysql.py < dump.sql >> out.sql
      echo "SET FOREIGN_KEY_CHECKS=1;" >> out.sql
      echo "    > importing out.sql"
      echo "Import data in MySQL database"
      mysql -f ${DATABASE_NAME} < out.sql
      echo "    > removing dump.sql and out.sql"
      rm -rf dump.sql out.sql
    fi

    # remove settings to launch install script to populate a default database
    echo "  > Launch install script to populate database (disabling localsettings)"
    mv ./LocalSettings.php ./LocalSettings.php.tmp
    php maintenance/install.php --dbuser $DATABASE_NAME --dbpass $DATABASE_NAME --dbname $DATABASE_NAME --pass MEDIAWIKI_ADMIN_PASSWORD $DATABASE_NAME Admin
    mv ./LocalSettings.php.tmp ./LocalSettings.php

    # skip rest of mediawiki init.
    echo "  > End of MySQL initialization. Please stop container, remove 'MYSQL_INIT=1' env and restart."
    exit 1
  else
    echo "  > Starting MySQL"
    service mysql start
  fi

  # Adding mysqldump to crontab
  echo "> Adding SQLite maintenance script to weekly cron"
  { \
    echo "#!/bin/sh" ; \
    echo "mysqldump --databases ${DATABASE_NAME} > ${DATA_DIR}/${DATABASE_NAME}.sql" ; \
  } > /etc/cron.weekly/MySQLDump && chmod 0500 /etc/cron.weekly/MySQLDump

  echo "* *  * * *  root  /usr/bin/flock -w 0 /dev/shm/cron.lock php ${WIKI_DIR}/maintenance/runJobs.php" > /etc/cron.d/runJobs
fi

if [ ! -z $VOLUME_TAR_URL ]
then
  echo "> Setup data dir using tar file at $VOLUME_TAR_URL"
  curl -fSL $VOLUME_TAR_URL | tar -xz -C $DATA_DIR
  ln -s ${DATA_DIR} data
  ln -s ${DATA_DIR}/download ../download
fi

if [ "$DATABASE_TYPE" = "sqlite" ]
then
  if [ -e ${DATABASE_FILE} ]
  then
    echo "> Using existing SQLite file"
  else
    echo "> Setting up SQlite database using template one"
    #Copy the "empty" database
    cp /tmp/my_wiki.sqlite ${DATABASE_FILE}
  fi
  # Allow to write on database
  echo "  > Setting permissions"
  chmod 644 ${DATABASE_FILE} && chown www-data:www-data ${DATABASE_FILE}
fi

# Allow to custom a few content at site root
if [ -d ${DATA_SITE_ROOT_DIR} ]
then
    echo "> Adding static files to site_root"
    for FILE in $(find ${DATA_SITE_ROOT_DIR} -type f)
    do
        echo "  > $(basename ${FILE})"
        FILE=$(readlink -f ${FILE})
        rm -f ../$(basename ${FILE})
        ln -s ${FILE} ../
    done
else
    echo "> Creating empty site_root"
    mkdir ${DATA_SITE_ROOT_DIR}
fi

# Set the secret token to download datadir
echo "> Setting secret export token"
sed -i s/?ACCESS_TOKEN?/$EXPORT_TOKEN/g ../export_data.php

# Fix latence problem
echo "> Removing locks"
rm -rf ${DATA_DIR}/locks

echo "> Running update script"
php maintenance/update.php --quick > $LOG_DIR/mw_update.log
if [ $? -gt 0 ]
then
  echo "/!\ update script failed:"
  cat $LOG_DIR/mw_update.log
fi

#change Admin password
echo "> Setting Admin user password"
php maintenance/createAndPromote.php --bureaucrat --sysop --force Admin ${MEDIAWIKI_ADMIN_PASSWORD}
