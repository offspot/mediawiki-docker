#debian + nginx
FROM nginx

#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

#######################
# ENVIRONNEMENT SETUP #
#######################

# Database config
ENV DATABASE_NAME my_wiki
ENV DATABASE_TYPE sqlite

# Directories locations
ENV HTML_DIR /var/www/html
ENV DATA_DIR /var/www/data
ENV WIKI_DIR ${HTML_DIR}/w

# Files config
ENV MEDIAWIKI_CONFIG_FILE_CUSTOM ./config/mediawiki/LocalSettings.custom.php
ENV MEDIAWIKI_CONFIG_FILE_BASE ./config/mediawiki/LocalSettings.php
ENV MEDIAWIKI_CONFIG_FILE_COMPOSER ./config/mediawiki/composer.json
ENV PARSOID_CONFIG_FILE ./config/parsoid/config.yaml
ENV NGINX_CONFIG_FILE_BASE ./config/nginx/nginx.conf
ENV NGINX_CONFIG_FILE_CUSTOM ./config/nginx/default.conf

# Media Wiki default admin password
ENV MEDIAWIKI_ADMIN_PASSWORD wikiadmin

# Media Wiki Version
ENV MEDIAWIKI_MAJOR_VERSION 1.31
ENV MEDIAWIKI_VERSION 1.31.0
ENV MEDIAWIKI_RC rc.0
ENV MEDIAWIKI_EXT_VERSION REL1_31
ENV PARSOID_VERSION v0.9.0

# Create directory for web site files and data files
RUN mkdir -p ${WIKI_DIR} && mkdir -p ${DATA_DIR} 

# Volumes to store database and medias (images...) files
VOLUME ${DATA_DIR}

# We work in WikiMedia root directory
WORKDIR ${WIKI_DIR} 

###################
# SOFTWARES SETUP #
###################

# add repos to install nodejs
RUN apt-get update && apt-get install -y --no-install-recommends \ 
    gnupg curl ca-certificates \
    && curl -sL https://deb.nodesource.com/setup_10.x | bash -

# System Dependencies.
RUN apt-get update && apt-get install -y \
  git \
  vim \
  unzip \
  imagemagick \
  libicu-dev \
  libav-tools \
  librsvg2-bin \
  poppler-utils \
  memcached \
  sqlite3 \
  mysql-client \
  mysql-server \
  cron \
  #PHP with needed extensions
  php7.0-fpm \
  php7.0-sqlite3 \
  php7.0-gd \
  php7.0-mysql \
  php7.0-intl \
  php7.0-mbstring \
  php7.0-xml \
  php7.0-curl \
  # Required for Math renderer
  texlive \		
  texlive-fonts-recommended \ 
  texlive-lang-greek \ 
  texlive-latex-recommended \
  texlive-latex-extra \
  build-essential \ 
  dvipng ocaml \ 
  cjk-latex \
  # Required for Parsoid
  redis-server \
  nodejs \
  # Ruired for Scribunto
  lua5.1 \
  # Required for SyntaxHighlighting
  python3 \
  # to generate locales
  locales \
  --no-install-recommends && rm -r /var/lib/apt/lists/*
	
# generate locale (set locale is used by MediaWiki scripts)
RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && locale-gen

# MediaWiki setup
RUN curl -fSL "https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_MAJOR_VERSION}/mediawiki-${MEDIAWIKI_VERSION}-${MEDIAWIKI_RC}.tar.gz" -o mediawiki.tar.gz \
	&& tar -xz --strip-components=1 -f mediawiki.tar.gz \
	&& rm mediawiki.tar.gz \
	&& chown -R www-data:www-data skins cache

# Parsoid setup
RUN git clone --quiet --depth=1 --branch ${PARSOID_VERSION} https://gerrit.wikimedia.org/r/p/mediawiki/services/parsoid \
  # install modules
  && cd parsoid \
  && npm install \
  && cd .. \
  # update node (need last version)
  && npm cache clean -f \
  && npm install -g n \
  && n stable   
  
######################################################
# ADD MEDIAWIKI EXTENSIONS NEEDED BY MEDIAWIKI/KIWIX #
######################################################

# Copy script to add an extension
COPY ./add_mw_extension.py /usr/local/bin/add_mw_extension
RUN chmod a+x /usr/local/bin/add_mw_extension 

# Call script to add all extensions needed by MediaWiki/Kiwix 
# Theses extensions can not be installed with composer
RUN add_mw_extension ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} Nuke Scribunto \
  UploadWizard TitleKey TitleBlacklist TimedMediaHandler wikihiero Math \
  timeline Echo MobileFrontend Thanks VisualEditor EventLogging GuidedTour \
  GeoData RSS TorBlock ConfirmEdit Babel cldr CleanChanges LocalisationUpdate \
  Translate UniversalLanguageSelector Mailgun Widgets

# To install Maps and Validator extensions with composer
# It's needed to get last version of this extensions
COPY ${MEDIAWIKI_CONFIG_FILE_COMPOSER} ./
# Update Composer config
RUN curl -fSL https://getcomposer.org/composer.phar -o composer.phar \
 && php composer.phar update --no-dev  

# Install MetaDescriptionTag extension from GitHub beacause it is not in official repository
RUN curl -fSL https://github.com/kolzchut/mediawiki-extensions-MetaDescriptionTag/archive/master.zip \
 -o MetaDescriptionTag.zip \
 && unzip MetaDescriptionTag.zip -d extensions/ \
 && mv extensions/mediawiki-extensions-MetaDescriptionTag-master extensions/MetaDescriptionTag \
 && rm -f MetaDescriptionTag.zip

# Install MwEmbedSupport extension from archive (the last version is 1.31) 
RUN curl -fSL https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/MwEmbedSupport/+archive/${MEDIAWIKI_EXT_VERSION}.tar.gz \
 -o MwEmbedSupport.tgz  \  
  && mkdir -p extensions/MwEmbedSupport \ 
  && tar -xzf MwEmbedSupport.tgz -C extensions/MwEmbedSupport \
  && rm -f MwEmbedSupport.tgz
  
# Install extension to send stats to Matomo server
RUN curl -fSL https://github.com/miraheze/MatomoAnalytics/archive/master.zip \
 -o master.zip  \  
  && unzip master.zip -d extensions/  \
  && mv extensions/MatomoAnalytics-master extensions/MatomoAnalytics \
  && rm -f master.zip

# Install extension to block bad behaviour
RUN curl -fSL https://downloads.wordpress.org/plugin/bad-behavior.2.2.22.zip \
 -o bad-behavior.zip \  
  && unzip bad-behavior.zip -d extensions/ \
  && mv extensions/bad-behavior extensions/BadBehaviour \
  && rm -f bad-behavior.zip

# Fix Math extension latex render
RUN sed -i 's/"latex /"\/usr\/bin\/latex /'     /var/www/html/w/extensions/Math/math/render.ml \
 && sed -i 's/"dvips /"\/usr\/bin\/dvips /'     /var/www/html/w/extensions/Math/math/render.ml \
 && sed -i 's/"convert /"\/usr\/bin\/convert /' /var/www/html/w/extensions/Math/math/render.ml \
 && sed -i 's/"dvipng /"\/usr\/bin\/dvipng /'   /var/www/html/w/extensions/Math/math/render.ml \
 # Clean Math extension 
 && make -C extensions/Math/math clean all \
 && make -C extensions/Math/texvccheck clean all 

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
COPY config/php-fpm/*.conf /etc/php/7.0/fpm/pool.d/
COPY config/php-fpm/*.ini /etc/php/7.0/fpm/conf.d/

# Configure Mediawiki
COPY ${MEDIAWIKI_CONFIG_FILE_BASE} ./LocalSettings.php
COPY ${MEDIAWIKI_CONFIG_FILE_CUSTOM} ./LocalSettings.custom.php

# Configure Parsoid
COPY ${PARSOID_CONFIG_FILE} ./parsoid/

# Needed to init database
COPY ./data/my_wiki.sqlite /tmp/

COPY ./assets/images/* ${HTML_DIR}/

# The files uploaded are in the data volume
RUN  mv ./images ./images.origin && ln -s /var/www/data/images ./images

# Remove configuration by web
#RUN rm -rf mw-config

###########
# START ! #
###########
  
# Run start script
COPY ./start.sh /usr/local/bin/
COPY ./mediawiki-init.sh /usr/local/bin/
COPY ./dump_for_mysql.py /usr/local/bin/
COPY ./start-services.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/*.sh
ENTRYPOINT "start.sh"
