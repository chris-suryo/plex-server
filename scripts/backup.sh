#!/usr/bin/env bash
# Back up app settings and databases (not the media itself, which is replaceable).
#
# Stops the stack for a consistent copy (a minute or two), then starts it again.
# Keeps the newest $KEEP archives (default 8) and deletes older ones.
#
# Usage:  sudo ./scripts/backup.sh [destination-dir]      (default: $DATA_ROOT/backups)
# Weekly: sudo crontab -e   then add:
#   0 4 * * 1 /home/<you>/plex-server/scripts/backup.sh >> /var/log/media-backup.log 2>&1
set -euo pipefail

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
[[ -f .env ]] || { echo "No .env found in $REPO_DIR" >&2; exit 1; }

env_get() { sed -n "s/^$1=//p" .env | tail -n1 | sed -e 's/^"//' -e 's/"$//'; }
CONFIG_ROOT="$(env_get CONFIG_ROOT)"; CONFIG_ROOT="${CONFIG_ROOT:-/docker/appdata}"
DATA_ROOT="$(env_get DATA_ROOT)";     DATA_ROOT="${DATA_ROOT:-/data}"

DEST="${1:-$DATA_ROOT/backups}"
KEEP="${KEEP:-8}"
ARCHIVE="$DEST/appdata-$(date +%Y%m%d-%H%M%S).tar.gz"
PLEX_DIR="plex/Library/Application Support/Plex Media Server"

mkdir -p "$DEST"
chmod 700 "$DEST"

echo "$(date -Is) stopping containers"
docker compose stop
trap 'echo "$(date -Is) starting containers"; docker compose start' EXIT

echo "$(date -Is) writing $ARCHIVE"
# Skip caches, logs and regenerable Plex thumbnails to keep the archive small.
tar -czf "$ARCHIVE" \
  --exclude="$PLEX_DIR/Cache" \
  --exclude="$PLEX_DIR/Crash Reports" \
  --exclude="$PLEX_DIR/Logs" \
  --exclude="$PLEX_DIR/Media" \
  --exclude="$PLEX_DIR/Codecs" \
  --exclude="*/logs" \
  --exclude="*/logs.db*" \
  -C "$CONFIG_ROOT" . \
  -C "$REPO_DIR" .env
chmod 600 "$ARCHIVE"

echo "$(date -Is) done: $(du -h "$ARCHIVE" | cut -f1)"

# Rotate old backups
find "$DEST" -maxdepth 1 -name 'appdata-*.tar.gz' -printf '%T@ %p\n' \
  | sort -rn | tail -n +"$((KEEP + 1))" | cut -d' ' -f2- \
  | xargs -r -d '\n' rm -v --
