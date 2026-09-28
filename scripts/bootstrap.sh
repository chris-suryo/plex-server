#!/usr/bin/env bash
# One-time setup for the media automation stack on "mediabox". Safe to re-run.
#
# Assumes the homelab repo (github.com/chris-suryo/pi-hole-ad-blocker) already set up
# the machine: Ubuntu, the data drive at /srv/storage, and Docker (Phases 6-7).
#
#   1. Creates .env from .env.example and fills in PUID, PGID and TZ
#   2. Creates the TRaSH Guides folder tree under DATA_ROOT and app folders under CONFIG_ROOT
#   3. Proves downloads -> media hardlinks work (same filesystem / ZFS dataset)
#   4. Validates compose.yaml
#
# Usage: ./scripts/bootstrap.sh     (as your normal user; it calls sudo itself)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# Read KEY=value from .env without sourcing it (values may contain spaces).
env_get() { sed -n "s/^$1=//p" .env | tail -n1 | sed -e 's/^"//' -e 's/"$//'; }

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root. It uses sudo when needed."
command -v sudo >/dev/null || die "sudo is required."
if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  die "Docker isn't installed. Run the homelab repo's scripts/05-install-docker.sh first."
fi

# ----------------------------------------------------------------- .env ----
if [[ ! -f .env ]]; then
  log "Creating .env from .env.example"
  cp .env.example .env
  tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  sed -i \
    -e "s|^PUID=.*|PUID=$(id -u)|" \
    -e "s|^PGID=.*|PGID=$(id -g)|" \
    -e "s|^TZ=.*|TZ=${tz:-Etc/UTC}|" \
    .env
else
  log ".env already exists; leaving it alone"
fi
chmod 600 .env

PUID="$(env_get PUID)";               PUID="${PUID:-1000}"
PGID="$(env_get PGID)";               PGID="${PGID:-1000}"
CONFIG_ROOT="$(env_get CONFIG_ROOT)"; CONFIG_ROOT="${CONFIG_ROOT:-/srv/appdata}"
DATA_ROOT="$(env_get DATA_ROOT)";     DATA_ROOT="${DATA_ROOT:-/srv/storage/data}"

# ------------------------------------------------------------ data drive ----
# DATA_ROOT must live on the data drive, not on the boot SSD's root filesystem.
probe="$DATA_ROOT"
while [[ ! -e "$probe" ]]; do probe="$(dirname "$probe")"; done
if [[ "$(findmnt -n -o TARGET --target "$probe")" == "/" ]]; then
  warn "$DATA_ROOT is on the boot SSD, not the data drive. Downloads would fill the SSD."
  warn "Finish the homelab repo's docs/07-mediabox-setup.md step E (data drive) first."
  if [[ -t 0 ]]; then
    read -rp "Continue anyway? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
  else
    die "Refusing to continue non-interactively."
  fi
fi

# --------------------------------------------------------------- folders ----
log "Creating media folders under $DATA_ROOT (TRaSH Guides layout)"
sudo mkdir -p \
  "$DATA_ROOT"/torrents/{movies,tv} \
  "$DATA_ROOT"/usenet/incomplete \
  "$DATA_ROOT"/usenet/complete/{movies,tv} \
  "$DATA_ROOT"/media/{movies,tv}
sudo chown -R "$PUID:$PGID" "$DATA_ROOT"
# Directories 775, files 664: owner and group can write, everyone can read.
sudo chmod -R a=,a+rX,u+w,g+w "$DATA_ROOT"

log "Creating app config folders under $CONFIG_ROOT"
for app in seerr sonarr radarr prowlarr bazarr tautulli recyclarr sabnzbd gluetun qbittorrent; do
  sudo mkdir -p "$CONFIG_ROOT/$app"
  sudo chown "$PUID:$PGID" "$CONFIG_ROOT/$app"
done
# Seerr always runs as UID 1000 inside its container, whatever PUID is.
sudo chown -R 1000:1000 "$CONFIG_ROOT/seerr"

# ------------------------------------------------------------ hardlinks ----
log "Checking that downloads can be hardlinked into the library"
src="$DATA_ROOT/torrents/.hardlink-test"
dst="$DATA_ROOT/media/.hardlink-test"
sudo -u "#$PUID" touch "$src"
if sudo -u "#$PUID" ln -f "$src" "$dst" 2>/dev/null; then
  echo "Hardlinks OK: imports will be instant and won't use extra space."
else
  warn "Can't hardlink from torrents/ to media/. They're on different filesystems or ZFS datasets."
  warn "Make $DATA_ROOT a single dataset/filesystem, or every import becomes a slow full copy."
fi
sudo rm -f "$src" "$dst"

# ------------------------------------------------------------- validate ----
log "Validating compose.yaml"
sudo docker compose config --quiet && echo "compose.yaml OK"

cat <<EOF

Done. Next steps (docs/02-configure-apps.md has the details):
  1. Edit .env: choose COMPOSE_PROFILES (usenet / torrent), fill in VPN details if using torrents.
  2. Start everything:   docker compose up -d
EOF
