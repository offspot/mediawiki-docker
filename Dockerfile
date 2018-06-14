#debian + nginx
FROM nginx

#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"

#######################
# ENVIRONNEMENT SETUP #
#######################

# Database name
ENV DATABASE_NAME my_wiki

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
  #PHP with needed extensions
  php7.0-fpm \
  php7.0-sqlite3 \
  php7.0-intl \
  php7.0-mbstring \
  php7.0-xml \
  php7.0-curl \
  # Required for Math renderer
  texlive \		
  texlive-fonts-recommended \ 
  texlive-lang-greek \ 
  texlive-latex-recommended	\			
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
RUN git clone --quiet https://gerrit.wikimedia.org/r/p/mediawiki/services/parsoid \
  # install modules
  && cd parsoid \
  && npm install \
  && cd .. \
  # update node (need last version)
  && npm cache clean -f \
  && npm install -g n \
  && n stable   
  
#set maximum file size upload
RUN { \
		echo 'upload_max_filesize = 100M'; \
		echo 'post_max_size = 100M'; \
	} > /etc/php/7.0/fpm/conf.d/90-wikifundi.ini  

######################################################
# ADD MEDIAWIKI EXTENSIONS NEEDED BY MEDIAWIKI/KIWIX #
######################################################

# Copy script to add an extension
COPY ./add_mw_extension.py /usr/local/bin/add_mw_extension
# To install Maps and Validator extensions with composer
# It's needed to get last version of this extensions
COPY ${MEDIAWIKI_CONFIG_FILE_COMPOSER} ./

RUN chmod a+x /usr/local/bin/add_mw_extension \
# Call script to add all extensions needed by MediaWiki/Kiwix 
# this extensions can not be installed with composer
&& add_mw_extension Nuke ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension Scribunto ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension UploadWizard ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension TitleKey ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension TitleBlacklist ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension MwEmbedSupport ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension TimedMediaHandler ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension wikihiero ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension Math ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension timeline ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension Echo ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension MobileFrontend ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension Thanks ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension VisualEditor ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension EventLogging ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension GuidedTour ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} \
&& add_mw_extension GeoData ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} 
#RUN add_mw_extension Wikibase ${MEDIAWIKI_EXT_VERSION} \

# Install MetaDescriptionTag extension from GitHub beacause it is not in official repository
RUN curl -fSL https://github.com/kolzchut/mediawiki-extensions-MetaDescriptionTag/archive/master.zip \
 -o MetaDescriptionTag.zip \
 && unzip MetaDescriptionTag.zip -d extensions/ \
 && mv extensions/mediawiki-extensions-MetaDescriptionTag-master extensions/MetaDescriptionTag 

# Clean Math extension 
RUN make -C extensions/Math/math clean all \
 && make -C extensions/Math/texvccheck clean all 

# Update Composer config
RUN curl -fSL https://getcomposer.org/composer.phar -o composer.phar \
 && php composer.phar update --no-dev  

# Fix owner \
RUN chown -R www-data:www-data extensions

##########################
# FINALIZE CONFIGURATION #
##########################

# Configure Nginx
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/default.conf /etc/nginx/conf.d/default.conf

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
COPY ./start-services.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/*.sh
ENTRYPOINT "start.sh"
