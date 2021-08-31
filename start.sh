#!/bin/sh

if [ ! -z "${HTPASSWORD}" ];
then
    # record htpassword for user `user``
    htpasswd -bc /etc/nginx/.htpassword user "${HTPASSWORD}"
    # append htpassword file path to nginx config
    sed -i -e '/auth_basic/a\ \ \ \ \ \ \ \ auth_basic_user_file /etc/nginx/.htpassword;' /etc/nginx/conf.d/default.conf
fi

service memcached start && \
mediawiki-init.sh && \
service php7.3-fpm start && \
service cron start

echo "Starting…"
exec "$@"
