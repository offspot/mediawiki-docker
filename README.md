OpenZIM Mediawiki Docker
========================

OpenZIM Mediawiki Docker offers a straight forward solution to deploy
Mediawki within on ly one Docker container.

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

user: Admin
pass: wikiadmin

Customise
---------

The `data` directory contains the database, images, file config and
images. Everything which makes your Mediawiki instance unique.

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
