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

* user: admin
* password: wikiadmin

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
---------------------------

```
docker build -t my_mediawiki .
```

Choose the database system
--------------------------

Set `DATABASE_TYPE` environnement variable at `sqlite` (default) or `mysql`.

Example:

```
sudo docker run -p 8080:80 \
  -e DATABASE_TYPE=mysql \
  -v <YOUR_CUSTOM_DATA_DIRECTORY>:/var/www/data -it openzim/mediawiki
```

The SQLite file is in  the data directory.
The MySQL data dir is the `mysql` sub-directory of the data directory.

SQLite database initialisation
------------------------------

If the SQLite file do not exist, the database is initialized with a empty
Mediawiki (only de `Main_Page` will exists).

MySQL database initialisation
-----------------------------
To init a MySQL databse set `MYSQL_INIT` to 1.

To choose the database name set `DATABASE_NAME`. Default is `my_wiki`.

If a file `import.sql` exist in data direcory, it used to init the database.

If a **SQLite file exist**, the content of the database is imported in the MySQL
database.

Example:

```
docker run -p 8080:80 \
  -e DATABASE_TYPE=mysql -e MYSQL_INIT=1 \
  -v /var/opt/florent/data/kiwix:/var/www/data -it openzim/mediawiki
```

Initialize the data directory with a tarball
--------------------------------------------

You can initialize your Mediawiki with existing images or a SQLite file
from a downloaded database. Set `VOLUME_TAR_URL` environnement variable.

Export data
-----------

To export data as a tarbal, use this URL:

`http://localhost:8080/export_data.php?token=EXPORT_TOKEN`

You can set the secret export token when you run the container:

`-e EXPORT_TOKEN=secret`

Generate a SQLite database file from a MySQL database
-----------------------------------------------------

Requierement:

* A running MySQL service with a Mediawiki 1.31 database
* Python 3
* MySQL db module for Python 3

To prepare your environnement run:

```
apt-get install python3 python3-pip libmysqlclient-dev
python3 -m virtualenv env
source env/bin/activate
pip install -r mysql2sqlite_requirement.txt
```

To generate the SQLite database file, run:

```
./mysql2sqlite.py <mysqlHost> <mysqlUser> <mysqlPassword> <mysqlDatabase> <sqliteFile>
```

With:

* mysqlHost : host where the MySQL service
* mysqlUser : MySQL user
* mysqlPassword : MySQL password
* sqliteFile : SQLite database filename to generate

Example:

```
./mysql2sqlite.py localhost root secret my_wiki.sqlite
```

Then copy SQLite file in your custom data directory used by the docker container.
Set the correct SQLite filename in `config/LocalSettings.custom.php`. If your
data diretory is empty, run once the container to initialized it.

If your MySQL Mediawiki database is in a lower version of 1.31, you might
migrate your database to 1.31 before generating the SQLite file. Then,
upgrade your Mediawiki version to 1.31 first and generate the SQLite file as
described above.

Author
------
Florent Kaisser <florent.pro@kaisser.name>
