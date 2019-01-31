OpenZIM Mediawiki Docker
========================

OpenZIM Mediawiki Docker offers a straight forward solution to deploy
Mediawki within only one Docker container.

Run
---

To create your Docker container:

```
sudo docker pull -a openzim/mediawiki
sudo docker run -p 8080:80 \
  -v <YOUR_CUSTOM_DATA_DIRECTORY>:/var/www/data -it openzim/mediawiki
```

Connect to your Docker container with your browser at
http://localhost:8080/

User credentials
----------------

user: admin
pass: wikiadmin

Customise
---------

The `data` directory contains the database, images, file config and
images. Everything which makes your Mediawiki instance unique. It is 
initialized when the container is created if needed files are not 
present (LocalSettings.custom.php and the MySQLite file).


You can customise the Mediawiki by editing your
`config/LocalSettings.custom.php`. If you want to know more, have a
look to this documentation:
https://www.mediawiki.org/wiki/Manual:LocalSettings.php

Backup
------

All your data are available in your `<YOUR_CUSTOM_DATA_DIRECTORY>`
data directory.

Build your own Docker image
-------------------------------

```
docker build -t my_mediawiki docker 
```

Generate a SQLite database file from a MySQL database
-----------------------------------------------------

Requierement :

- A running MySQL service with a Wikimedia 1.31 database
- Python 3
- MySQLdb et sqlite3 module for Python 3 

To install Python 3 and required modules on Debian/Ubuntu system run :

```
apt-get install python3 python-sqlite python3-mysqldb
```

To generate the SQLite database file, run :

```
./mysql2sqlite.py <mysqlHost> <mysqlUser> <mysqlPassword> <mysqlDatabase> <sqliteFile>
```

With :

- mysqlHost : host where the MySQL service
- mysqlUser : MySQL user
- mysqlPassword : MySQL password
- sqliteFile : SQLite database filename to generate

Ex : 

```
./mysql2sqlite.py localhost root secret my_wiki.sqlite
```

Then copy SQLite file in your custom data directory used by the docker container. 
Set the correct SQLite filename in `config/LocalSettings.custom.php`. If your 
data diretory is empty, run once the container to initialized it.

If your MySQL wikimedia database is in a lower version of 1.31, you might 
migrate your database to 1.31 before generate the SQLite file because
Wikimedia maintenance seem can't do that with a SQLite database. Then,
upgrade your Wikimedia version to 1.31 first and generate the SQLite file as
described above.

Author
------
Florent Kaisser <florent.pro@kaisser.name>
