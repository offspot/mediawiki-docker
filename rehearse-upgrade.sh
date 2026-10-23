#!/bin/bash
# Stage a freshly-restored borgmatic backup into a disposable Docker
# container, to rehearse a MediaWiki version upgrade before touching
# production. See UPGRADE.md for the full procedure this automates.
#
# Usage:
#   ./rehearse-upgrade.sh <borg-restore-root> <data-dir> <image-tag> [name] [port] [url]
#
#   <borg-restore-root>  A freshly restored borgmatic backup root,
#                         containing storage/{config,images,site_root}
#                         and root/.borgmatic/mysql_databases/<service>/my_wiki
#   <data-dir>            Scratch directory to stage the container's data
#                         volume in. Must not already exist, unless FORCE=1.
#   <image-tag>           Image to test, e.g. ghcr.io/offspot/mediawiki:v1.43.11
#   [name]                Container name prefix (default: mw-rehearsal)
#   [port]                Host port to publish (default: 18080)
#   [url]                 External URL MediaWiki should think it's served
#                         at (default: http://localhost:<port>)
#
# Set FORCE=1 to wipe an existing <data-dir> first instead of aborting.

set -euo pipefail

BORG_ROOT="${1:?borg-restore-root required}"
DATA_DIR="${2:?data-dir required}"
IMAGE="${3:?image-tag required}"
NAME="${4:-mw-rehearsal}"
PORT="${5:-18080}"
URL="${6:-http://localhost:${PORT}}"

STORAGE_DIR="${BORG_ROOT}/storage"
MYSQL_DBS_DIR="${BORG_ROOT}/root/.borgmatic/mysql_databases"

log() { echo ">>> $*"; }

# --- validate inputs -------------------------------------------------------

[ -d "$STORAGE_DIR/config" ] || { echo "No $STORAGE_DIR/config - is this really a borgmatic restore root?"; exit 1; }
[ -d "$MYSQL_DBS_DIR" ] || { echo "No $MYSQL_DBS_DIR - is this really a borgmatic restore root?"; exit 1; }

mapfile -t SERVICES < <(find "$MYSQL_DBS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
if [ "${#SERVICES[@]}" -ne 1 ]; then
  echo "Expected exactly one service dir under $MYSQL_DBS_DIR, found: ${SERVICES[*]:-none}"
  echo "Set SERVICE=<name> explicitly if auto-detection is wrong."
  exit 1
fi
SERVICE="${SERVICE:-${SERVICES[0]}}"
DUMP_FILE="${MYSQL_DBS_DIR}/${SERVICE}/my_wiki"
[ -f "$DUMP_FILE" ] || { echo "No dump at $DUMP_FILE"; exit 1; }

if [ -e "$DATA_DIR" ]; then
  if [ "${FORCE:-0}" = "1" ]; then
    log "FORCE=1: wiping existing $DATA_DIR"
    docker run --rm -v "$(realpath "$DATA_DIR"):/data" alpine rm -rf /data
  else
    echo "$DATA_DIR already exists. Remove it, pick a different path, or set FORCE=1."
    exit 1
  fi
fi

# --- stage the data directory ----------------------------------------------

log "Staging $DATA_DIR from $BORG_ROOT (service: $SERVICE)"
mkdir -p "$DATA_DIR"
cp -a "$STORAGE_DIR/config" "$DATA_DIR/config"
cp -a "$STORAGE_DIR/images" "$DATA_DIR/images"
[ -d "$STORAGE_DIR/site_root" ] && cp -a "$STORAGE_DIR/site_root" "$DATA_DIR/site_root"
cp "$DUMP_FILE" "$DATA_DIR/import.sql"

INIT_NAME="${NAME}-init"
docker rm -f "$INIT_NAME" "$NAME" >/dev/null 2>&1 || true

# --- MYSQL_INIT pass: import the dump, run install.php's idempotent setup --

log "Starting $INIT_NAME (MYSQL_INIT=1) to import the dump..."
docker run -d --name "$INIT_NAME" \
  -v "$(realpath "$DATA_DIR"):/var/www/data" \
  -e DATABASE_TYPE=mysql -e MYSQL_INIT=1 -e URL="$URL" \
  "$IMAGE" >/dev/null

log "Waiting for the import + install.php pass to finish (this can take a while for large dumps)..."
for _ in $(seq 1 180); do
  if docker logs "$INIT_NAME" 2>&1 | grep -q "End of MySQL initialization"; then
    break
  fi
  if ! docker ps --filter "name=^${INIT_NAME}$" --format '{{.Names}}' | grep -q "$INIT_NAME"; then
    echo "$INIT_NAME exited unexpectedly:"
    docker logs "$INIT_NAME" 2>&1 | tail -40
    exit 1
  fi
  sleep 10
done
if ! docker logs "$INIT_NAME" 2>&1 | grep -q "End of MySQL initialization"; then
  echo "Timed out waiting for the import pass. Last log lines:"
  docker logs "$INIT_NAME" 2>&1 | tail -40
  exit 1
fi
log "Import pass complete."

# Shut MariaDB down cleanly before removing the container: force-killing a
# live mariadbd (docker rm -f) can corrupt its system tables, which then
# silently falls back to re-bootstrapping an empty database on next start.
log "Shutting MariaDB down cleanly..."
docker exec "$INIT_NAME" mysqladmin shutdown || true
sleep 2
docker stop "$INIT_NAME" >/dev/null
docker rm "$INIT_NAME" >/dev/null

# --- the real pass: this is what actually runs update.php against the ----
# --- restored, pre-upgrade schema for the first time ------------------------

log "Starting $NAME for real (this runs maintenance/update.php against the restored data)..."
docker run -d --name "$NAME" -p "${PORT}:80" \
  -v "$(realpath "$DATA_DIR"):/var/www/data" \
  -e DATABASE_TYPE=mysql -e URL="$URL" \
  "$IMAGE" >/dev/null

log "Waiting for the update.php pass to finish..."
for _ in $(seq 1 60); do
  if docker logs "$NAME" 2>&1 | grep -qE "Password set\.|update script failed"; then
    break
  fi
  sleep 5
done

if docker logs "$NAME" 2>&1 | grep -q "update script failed"; then
  echo
  echo "/!\\ update.php failed. Full update log is at ${DATA_DIR}/log/mw_update.log"
  echo "Container $NAME is left running for inspection."
  exit 1
fi

echo
log "Done. $NAME is up at $URL (published on host port $PORT)."
log "Log in as Admin with the MEDIAWIKI_ADMIN_PASSWORD baked into the image (default: mediawikipass) to verify edit/upload."
log "When finished: docker exec $NAME mysqladmin shutdown && docker stop $NAME && docker rm $NAME"
