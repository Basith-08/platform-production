#!/usr/bin/env bash
# Remove only unused Docker images older than the rollback grace period.
# Volumes, containers, and active images are never pruned here.

set -euo pipefail

RETENTION="${DOCKER_IMAGE_PRUNE_UNTIL:-168h}"
if ! [[ "${RETENTION}" =~ ^[0-9]+[smhdw]$ ]]; then
  echo "Invalid DOCKER_IMAGE_PRUNE_UNTIL: ${RETENTION}" >&2
  exit 1
fi

command -v docker >/dev/null 2>&1 || { echo "Docker is not installed." >&2; exit 1; }
docker info >/dev/null
echo "Pruning unused Docker images older than ${RETENTION}; volumes and containers are untouched."
docker image prune -a -f --filter "until=${RETENTION}"
echo "Docker image housekeeping complete."
