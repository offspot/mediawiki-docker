#!/bin/sh

handle-htpassword-opt.sh
service memcached start && \
mediawiki-init.sh && \
service php8.4-fpm start && \
service cron start

# Stop the web-facing services first (so in-flight requests don't lose
# their DB mid-request), then MariaDB last, and cleanly: an abrupt kill
# of mariadbd can corrupt its system tables, silently causing the next
# start to bootstrap an empty database instead of using the real data.
shutdown() {
  echo "Shutting down…"
  kill -TERM "$child" 2>/dev/null
  service cron stop 2>/dev/null
  service php8.4-fpm stop 2>/dev/null
  service memcached stop 2>/dev/null
  if [ "$DATABASE_TYPE" = "mysql" ]; then
    service mariadb stop 2>/dev/null
  fi
}
trap shutdown TERM INT QUIT

echo "Starting…"
"$@" &
child=$!
wait "$child"
