#!/usr/bin/env bash
# One-time host setup for the media server. Safe to re-run.
#
#   1. Installs Docker Engine + the Compose plugin (Ubuntu/Debian)
#   2. Creates .env from .env.example and fills in PUID, PGID and TZ
#   3. Creates the /data folder tree and app config folders with the right owners
#   4. Checks for the Intel iGPU (/dev/dri) that Plex uses for transcoding
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
# shellcheck source=/dev/null
. /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) die "This script supports Ubuntu and Debian only (found '${ID:-unknown}')." ;;
esac

# --------------------------------------------------------------- docker ----
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
  log "Docker already installed: $(docker --version)"
else
  log "Installing Docker Engine and Compose plugin (official Docker apt repo)"
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo systemctl enable --now docker >/dev/null

NEED_RELOGIN=0
if ! id -nG "$USER" | grep -qw docker; then
  log "Adding $USER to the docker group (so you don't need sudo for docker)"
  sudo usermod -aG docker "$USER"
  NEED_RELOGIN=1
fi

# intel_gpu_top lets you watch Quick Sync working during a transcode.
if ! command -v intel_gpu_top >/dev/null; then
  log "Installing intel-gpu-tools"
  sudo apt-get install -y intel-gpu-tools || warn "Could not install intel-gpu-tools (optional)."
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
CONFIG_ROOT="$(env_get CONFIG_ROOT)"; CONFIG_ROOT="${CONFIG_ROOT:-/docker/appdata}"
DATA_ROOT="$(env_get DATA_ROOT)";     DATA_ROOT="${DATA_ROOT:-/data}"

# -------------------------------------------------------------- folders ----
if ! mountpoint -q "$DATA_ROOT"; then
  warn "$DATA_ROOT is not a mounted drive. Media would fill up your SSD."
  warn "Mount the big HDD at $DATA_ROOT first (docs/03-storage.md)."
  if [[ -t 0 ]]; then
    read -rp "Continue anyway? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
  else
    die "Refusing to continue non-interactively."
  fi
fi

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
for app in plex seerr sonarr radarr prowlarr bazarr tautulli recyclarr sabnzbd gluetun qbittorrent; do
  sudo mkdir -p "$CONFIG_ROOT/$app"
done
sudo chown -R "$PUID:$PGID" "$CONFIG_ROOT"
# Seerr always runs as UID 1000 inside its container, whatever PUID is.
sudo chown -R 1000:1000 "$CONFIG_ROOT/seerr"

# ------------------------------------------------------------ hardware ----
if [[ -e /dev/dri/renderD128 ]]; then
  log "Intel iGPU found (/dev/dri/renderD128). Plex can use Quick Sync (with Plex Pass)."
else
  warn "No /dev/dri/renderD128 found. The Plex container will not start without it."
  warn "Enable the iGPU in the BIOS (docs/01-hardware.md), reboot, and re-run this script."
fi

# ------------------------------------------------------------- validate ----
log "Validating compose.yaml"
sudo docker compose config --quiet && echo "compose.yaml OK"

cat <<EOF

Done. Next steps (docs/04-configure-apps.md has the details):
  1. Edit .env: choose COMPOSE_PROFILES (usenet / torrent), fill in VPN details if using torrents.
  2. Get a claim token from https://www.plex.tv/claim and paste it into PLEX_CLAIM in .env.
  3. Start everything:   docker compose up -d
EOF
if [[ $NEED_RELOGIN -eq 1 ]]; then
  echo
  warn "Log out and back in (or reboot) so the docker group applies. Until then, use 'sudo docker ...'."
fi
