# nginx on debian (buster-slim ATM)
FROM nginx:1.21.3

#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="hsstan"
LABEL org.opencontainers.image.source https://github.com/hsstan/mediawiki-docker

#######################
# ENVIRONNEMENT SETUP #
#######################

# Database config
ENV DATABASE_NAME=my_wiki \
    DATABASE_TYPE=sqlite \
# Directories locations
    HTML_DIR=/var/www/html \
    DATA_DIR=/var/www/data \
# Files config
    MEDIAWIKI_CONFIG_FILE_CUSTOM=./config/mediawiki/LocalSettings.custom.php \
    MEDIAWIKI_CONFIG_FILE_BASE=./config/mediawiki/LocalSettings.php \
    NGINX_CONFIG_FILE_BASE=./config/nginx/nginx.conf \
    NGINX_CONFIG_FILE_CUSTOM=./config/nginx/default.conf \
# Media Wiki default admin password
    MEDIAWIKI_ADMIN_PASSWORD=mediawikipass \
# Media Wiki Version
    MEDIAWIKI_MAJOR_VERSION=1.36 \
    MEDIAWIKI_VERSION=1.36.1 \
    MEDIAWIKI_EXT_VERSION=REL1_36

#Keep it separated because it depends on other env variables
ENV WIKI_DIR ${HTML_DIR}/w

# Create directory for web site files and data files
RUN mkdir -p ${WIKI_DIR} && mkdir -p ${DATA_DIR}

# Volumes to store database and medias (images...) files
VOLUME ${DATA_DIR}

# We work in WikiMedia root directory
WORKDIR ${WIKI_DIR}

###################
# SOFTWARES SETUP #
###################

# Install Node.js
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \ 
    curl \
    gnupg \  
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# System Dependencies.
RUN apt-get update && apt-get install -y \
  # to work with HTTPASSWORD environ
  apache2-utils \
  build-essential \
  cron \
  cjk-latex \
  dvipng ocaml \
  # Required for PagedTiffHandler
  exiv2 \
  ffmpeg \  
  # for Timeline ext
  fonts-freefont-ttf \
  git \
  imagemagick \
  libicu-dev \
  librsvg2-bin \    
  # Required for PagedTiffHandler
  libtiff-tools \
  # Required for Scribunto
  # Requuired for VipsScaler
  libvips-tools \
  # to generate locales
  locales \
  lua5.1 \
  poppler-utils \
  mariadb-client \
  mariadb-server \
  memcached \
  #PHP with needed extensions
  php7.3-fpm \
  php7.3-sqlite3 \
  php7.3-gd \
  php7.3-mysql \
  php7.3-intl \
  php7.3-mbstring \
  php7.3-xml \
  php7.3-curl \
  # Required for SyntaxHighlighting
  python3 \
  sqlite3 \
  # Required for Math renderer
  texlive \
  texlive-fonts-recommended \
  texlive-lang-greek \
  texlive-latex-recommended \
  texlive-latex-extra \
  # for Timeline ext
  ttf-unifont \
  vim \
  unzip \
  --no-install-recommends && rm -r /var/lib/apt/lists/*

# generate locale (set locale is used by MediaWiki scripts)
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# MediaWiki setup
RUN curl -fSL "https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_MAJOR_VERSION}/mediawiki-${MEDIAWIKI_VERSION}.tar.gz" -o mediawiki.tar.gz \
	&& tar -xz --strip-components=1 -f mediawiki.tar.gz \
	&& rm mediawiki.tar.gz \
	&& chown -R www-data:www-data skins cache

######################################################
# ADD MEDIAWIKI EXTENSIONS NEEDED BY MEDIAWIKI/KIWIX #
######################################################

# Copy script to add an extension
COPY ./add_mw_extension.py /usr/local/bin/add_mw_extension
RUN chmod a+x /usr/local/bin/add_mw_extension

# Call script to add all extensions needed by MediaWiki/Kiwix
# Theses extensions can not be installed with composer
RUN add_mw_extension ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
  AdvancedSearch \
  ArticleCreationWorkflow \
  Babel \
  CategoryTree \
  CharInsert \
  CiteThisPage \ 
  cldr \
  CleanChanges \ 
  CodeEditor \
  CodeMirror \
  ContentTranslation \
  ConfirmEdit \ 
  Disambiguator \
  DismissableSiteNotice \
  FileExporter \
  Echo \
  GeoData \ 
  #GettingStarted \
  JsonConfig \ 
  Kartographer \
  LabeledSectionTransclusion \
  Linter \
  # LocalisationUpdate \
  Math \
  MobileFrontend \
  MultimediaViewer \
  Nuke \ 
  PageAssessments \
  PagedTiffHandler \
  PageImages \
  PageViewInfo \
  Poem \
  RSS \
  SandboxLink \
  Scribunto \
  Score \ 
  TemplateData \
  TemplateSandbox \
  TemplateStyles \
  TemplateWizard \
  TextExtracts \
  Thanks \ 
  TimedMediaHandler \
  timeline \
  TitleBlacklist \
  TitleKey \
  TorBlock \
  Translate \
  UniversalLanguageSelector \
  UploadWizard \
  VipsScaler \
  VisualEditor \
  Widgets \ 
  wikihiero \
  WikiLove 

RUN curl -L -o mwExtUpgrader.phar  https://github.com/RazeSoldier/mwExtUpgrader/releases/download/v0.1.4/mwExtUpgrader.phar && \
  php mwExtUpgrader.phar

# add symlink to timeline font (https://gerrit.wikimedia.org/r/c/operations/mediawiki-config/fonts/+/321560/)
RUN cd /usr/share/fonts/truetype/freefont && ln -s FreeSans.ttf FreeSans

# Install composer-listed extensions
RUN curl -fSL https://download.kiwix.org/dev/composer2.phar -o composer.phar \
 && php composer.phar install --no-dev

# Install MetaDescriptionTag extension from GitHub beacause it is not in official repository
RUN curl -fSL https://github.com/kolzchut/mediawiki-extensions-MetaDescriptionTag/archive/master.zip \
 -o MetaDescriptionTag.zip \
 && unzip MetaDescriptionTag.zip -d extensions/ \
 && mv extensions/mediawiki-extensions-MetaDescriptionTag-master extensions/MetaDescriptionTag \
 && rm -f MetaDescriptionTag.zip

# Install IFrame extension
RUN curl -fSL https://github.com/sigbertklinke/Iframe/archive/master.zip \
 -o Iframe.zip \
 && unzip Iframe.zip -d extensions/ \
 && mv extensions/Iframe-master extensions/Iframe \
 && rm -f Iframe.zip

# Install extension to send stats to Matomo server
RUN curl -fSL https://codeload.github.com/miraheze/MatomoAnalytics/zip/447580be1d29159c53b4646b420cb804d1bcc62a \
 -o master.zip  \
  && unzip master.zip -d extensions/  \
  && mv extensions/MatomoAnalytics-447580be1d29159c53b4646b420cb804d1bcc62a extensions/MatomoAnalytics \
  && rm -f master.zip

# Install extension to block bad behaviour
RUN curl -fSL https://downloads.wordpress.org/plugin/bad-behavior.2.2.22.zip \
 -o bad-behavior.zip \
  && unzip bad-behavior.zip -d extensions/ \
  && mv extensions/bad-behavior extensions/BadBehaviour \
  && rm -f bad-behavior.zip

RUN curl -fSL https://github.com/rgaudin/mediawiki-mailgun/archive/refs/heads/REL1_36.zip \
 -o Mailgun.zip \
 && unzip Mailgun.zip -d extensions/ \
 && mv extensions/mediawiki-mailgun-REL1_36/ extensions/Mailgun \
 && rm -f Mailgun.zip

# Finalize Mailgun extension install
RUN cd extensions/Mailgun && php ../../composer.phar update && cd ../..

# Fix owner \
RUN chown -R www-data:www-data extensions

##########################
# FINALIZE CONFIGURATION #
##########################

# Configure Nginx
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/default.conf /etc/nginx/conf.d/default.conf

# Configure PHP-fpm
COPY config/php-fpm/*.conf /etc/php/7.3/fpm/pool.d/
COPY config/php-fpm/*.ini /etc/php/7.3/fpm/conf.d/

# Configure Mediawiki
COPY ${MEDIAWIKI_CONFIG_FILE_BASE} ./LocalSettings.php
COPY ${MEDIAWIKI_CONFIG_FILE_CUSTOM} ./LocalSettings.custom.php

# Configure Parsoid
# COPY ${PARSOID_CONFIG_FILE} ./parsoid/

# Needed to init database
COPY ./data/my_wiki.sqlite /tmp/

# Few default images
COPY ./assets/images/* ${HTML_DIR}/

# The files uploaded are in the data volume
RUN  mv ./images ./images.origin && ln -s /var/www/data/images ./images

COPY ./export_data.php ../

# allow remote connections (to backup for instance)
RUN sed -i "s/bind-address            = 127.0.0.1/bind-address            = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf 

# Remove configuration by web
#RUN rm -rf mw-config

###########
# START ! #
###########

# Run start script
COPY ./handle-htpassword-opt.sh /usr/local/bin/
COPY ./start.sh /usr/local/bin/
COPY ./mediawiki-init.sh /usr/local/bin/
COPY ./dump_for_mysql.py /usr/local/bin/
RUN chmod a+x /usr/local/bin/*.sh
ENTRYPOINT ["start.sh"]
CMD ["nginx", "-g", "daemon off;"]
