#!/usr/bin/env bash
# Update everything: pull the latest repo config and container images, then
# recreate only the containers that changed.
#
# Usage: ./scripts/update.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Pulling repo changes"
git pull --ff-only || echo "WARN: git pull skipped (local changes or no network); continuing."

echo "==> Pulling container images"
docker compose pull

echo "==> Recreating changed containers"
docker compose up -d --remove-orphans

echo "==> Removing old images"
docker image prune -f

docker compose ps
