# nginx on debian (trixie)
FROM nginx:stable-trixie

#
# Author : Florent Kaisser <florent.pro@kaisser.name>
#
LABEL maintainer="kiwix"
LABEL org.opencontainers.image.source https://github.com/offspot/mediawiki-docker

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
ENV NGINX_CONFIG_FILE_BASE ./config/nginx/nginx.conf
ENV NGINX_CONFIG_FILE_CUSTOM ./config/nginx/default.conf

# Media Wiki default admin password
ENV MEDIAWIKI_ADMIN_PASSWORD mediawikipass

# Media Wiki Version (LTS only; see UPGRADE.md)
ENV MEDIAWIKI_MAJOR_VERSION 1.43
ENV MEDIAWIKI_VERSION 1.43.11
ENV MEDIAWIKI_EXT_VERSION REL1_43

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
    gnupg curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# System Dependencies.
RUN apt-get update && apt-get install -y \
  git \
  vim \
  unzip \
  imagemagick \
  libicu-dev \
  ffmpeg \
  librsvg2-bin \
  poppler-utils \
  memcached \
  sqlite3 \
  mariadb-client \
  mariadb-server \
  cron \
  #PHP with needed extensions
  php8.4-fpm \
  php8.4-sqlite3 \
  php8.4-gd \
  php8.4-mysql \
  php8.4-intl \
  php8.4-mbstring \
  php8.4-xml \
  php8.4-curl \
  # for Timeline ext
  fonts-freefont-ttf \
  fonts-unifont \
  # Required for Math renderer
  texlive \
  texlive-fonts-recommended \
  texlive-lang-greek \
  texlive-latex-recommended \
  texlive-latex-extra \
  build-essential \
  dvipng ocaml \
  cjk-latex \
  # Ruired for Scribunto
  lua5.1 \
  # Required for SyntaxHighlighting
  python3 \
  # Required for PagedTiffHandler
  exiv2 \
  libtiff-tools \
  # Requuired for VipsScaler
  libvips-tools \
  # to generate locales
  locales \
  # to work with HTTPASSWORD environ
  apache2-utils \
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
RUN add_mw_extension ${MEDIAWIKI_EXT_VERSION} ${WIKI_DIR} Nuke Scribunto Renameuser \
  UploadWizard TitleKey TitleBlacklist TimedMediaHandler wikihiero Math \
  timeline Echo MobileFrontend Thanks VisualEditor Babel \
  GeoData RSS TorBlock ConfirmEdit cldr CleanChanges \
  Translate UniversalLanguageSelector Widgets TemplateStyles \
  CiteThisPage ContentTranslation TemplateSandbox CodeEditor CodeMirror \
  CategoryTree CharInsert Kartographer LabeledSectionTransclusion Poem \
  Score VipsScaler PageImages AdvancedSearch \
  ArticleCreationWorkflow Disambiguator DismissableSiteNotice FileExporter \
  JsonConfig MultimediaViewer PageViewInfo SandboxLink TemplateWizard WikiLove \
  PagedTiffHandler TextExtracts PageAssessments Linter TemplateData

# add symlink to timeline font (https://gerrit.wikimedia.org/r/c/operations/mediawiki-config/fonts/+/321560/)
RUN cd /usr/share/fonts/truetype/freefont && ln -s FreeSans.ttf FreeSans

# Install composer-listed extensions
RUN curl -fsSL https://getcomposer.org/installer -o composer-setup.php \
 && php composer-setup.php --install-dir=. --filename=composer.phar \
 && rm composer-setup.php \
 && php composer.phar install --no-dev

# Install MetaDescriptionTag extension from GitHub (third-party, not mirrored under wikimedia/)
RUN curl -fSL "https://github.com/kolzchut/mediawiki-extensions-MetaDescriptionTag/archive/refs/heads/${MEDIAWIKI_EXT_VERSION}.tar.gz" \
 -o MetaDescriptionTag.tar.gz \
 && mkdir -p extensions/MetaDescriptionTag \
 && tar -xzf MetaDescriptionTag.tar.gz --strip-components=1 -C extensions/MetaDescriptionTag \
 && rm -f MetaDescriptionTag.tar.gz

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
COPY config/php-fpm/*.conf /etc/php/8.4/fpm/pool.d/
COPY config/php-fpm/*.ini /etc/php/8.4/fpm/conf.d/

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
