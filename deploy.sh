#!/bin/bash
# RepPlusApp Deployment Script

set -euo pipefail

cd "$(dirname "$0")"

# Compose v2 ("docker compose", with a space) is required.
#
# The v1 python client (docker-compose 1.29.2) crashes with
# KeyError: 'ContainerConfig' whenever it recreates a container whose image was
# built by a modern docker daemon - and it removes the old container before it
# gets there, so a failed deploy leaves the site down. v1 and v2 also disagree
# about image names: v1 tags repplusapp_repplus (underscore), v2 looks for
# repplusapp-repplus (hyphen), so mixing them silently starts a stale image
# instead of the one just built.
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
else
  echo "ERROR: docker compose (v2) not found."
  echo "Install it with:  sudo apt install docker-compose-plugin"
  echo "Do not fall back to docker-compose (v1) - it breaks on recreate."
  exit 1
fi

echo "=== RepPlusApp Deployment ==="
echo "Using: $($COMPOSE version)"
echo

# The build is the slow part (it reinstalls the R packages). The current
# container keeps serving throughout it.
echo "Building image - the running site stays up during this..."
$COMPOSE build

# Only now is the site interrupted, for the few seconds it takes to swap
# containers. container_name is pinned in docker-compose.yml, so there is no
# rolling replacement: the old container must go before the new one starts.
echo "Swapping container..."
if ! $COMPOSE up -d --force-recreate --remove-orphans; then
  # A container called "repplus" left behind by an older compose project (or a
  # manual docker run) blocks creation, since the name is pinned.
  echo "Swap failed - clearing a leftover 'repplus' container and retrying..."
  docker rm -f repplus 2>/dev/null || true
  $COMPOSE up -d --force-recreate
fi

# The app is published on the docker bridge address, not loopback, so nginx can
# reach it while the host's public interface cannot. curl localhost:3838 will
# always come back empty - use the bridge IP.
APP_URL="http://172.17.0.1:3838/webgrid/"

echo "Waiting for the app to answer..."
for _ in $(seq 1 30); do
  if curl -sf --max-time 3 "$APP_URL" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

VERSION="$(curl -s --max-time 5 "$APP_URL" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || true)"

echo
docker ps --filter name=repplus --format "  {{.Names}} | {{.Image}} | {{.Status}}"
echo
if [ -n "$VERSION" ]; then
  echo "=== Deployment Complete - serving $VERSION ==="
else
  echo "=== WARNING: the app did not answer on $APP_URL ==="
  echo "Check the logs with:  docker logs --tail 50 repplus"
  exit 1
fi
echo "Public URL: https://webgrid.online/"
