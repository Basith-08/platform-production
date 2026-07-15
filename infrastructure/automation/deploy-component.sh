#!/usr/bin/env bash
#
# Applies one already-synced platform-service component under
# /srv/platform/<component> and verifies it came up healthy.
#
# This script runs ON the production server. It is invoked over SSH by
# .github/workflows/deploy-component.yml, after that workflow has rsynced
# infrastructure/<component>/ from the platform-production repository into
# /srv/platform/<component>/. It is not run ad hoc — see
# docs/04-operations/OPS-011-deploy-platform-service.md.
#
# Component kinds, detected by the files present in the synced directory:
#   - compose.yaml       -> docker compose pull && docker compose up -d,
#                            then poll container health.
#   - crontab            -> install the crontab for the invoking user
#                            (backup jobs; no long-running container).
#   - create-networks.sh -> re-run the idempotent shared-network setup.
#
# Reference: docs/01-architecture/ARCH-005-deployment-strategy.md
#            docs/03-standards/STD-011-platform-deployment-pipeline-standard.md
#            docs/04-operations/OPS-011-deploy-platform-service.md

set -euo pipefail

COMPONENT="${1:?Usage: deploy-component.sh <component>}"
COMPONENT_DIR="/srv/platform/${COMPONENT}"
HEALTH_RETRIES="${HEALTH_RETRIES:-24}"
HEALTH_INTERVAL_SECONDS="${HEALTH_INTERVAL_SECONDS:-10}"

[ -d "${COMPONENT_DIR}" ] || {
  echo "No such component directory: ${COMPONENT_DIR}" >&2
  echo "Expected it to already exist from OPS-001 provisioning (bootstrap.sh)." >&2
  exit 1
}

cd "${COMPONENT_DIR}"

container_status() {
  # Prints "<name> <status>" per container, one per line. Prefers the
  # container's healthcheck status; falls back to its run state for the
  # rare service without one.
  local cid
  for cid in $(docker compose ps -q); do
    docker inspect \
      -f '{{.Name}} {{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "${cid}"
  done
}

wait_for_healthy() {
  local attempt statuses unhealthy
  for attempt in $(seq 1 "${HEALTH_RETRIES}"); do
    statuses="$(container_status)"
    unhealthy="$(echo "${statuses}" | awk '$2!="healthy" && $2!="running" {print}')"
    if [ -z "${unhealthy}" ]; then
      echo "==> [${COMPONENT}] All containers healthy:"
      echo "${statuses}"
      return 0
    fi
    echo "    ...waiting for containers to become healthy (attempt ${attempt}/${HEALTH_RETRIES}):"
    echo "${unhealthy}"
    sleep "${HEALTH_INTERVAL_SECONDS}"
  done
  echo "==> [${COMPONENT}] FAILED health check after $((HEALTH_RETRIES * HEALTH_INTERVAL_SECONDS))s" >&2
  docker compose ps
  docker compose logs --tail=50
  return 1
}

if [ -f compose.yaml ]; then
  echo "==> [${COMPONENT}] Pulling images"
  docker compose pull

  echo "==> [${COMPONENT}] Applying"
  docker compose up -d --remove-orphans

  echo "==> [${COMPONENT}] Verifying health"
  wait_for_healthy

elif [ -f crontab ]; then
  echo "==> [${COMPONENT}] Installing crontab for $(whoami)"
  chmod +x ./*.sh
  crontab crontab
  echo "==> [${COMPONENT}] Installed:"
  crontab -l

elif [ -f create-networks.sh ]; then
  echo "==> [${COMPONENT}] Ensuring shared networks exist"
  chmod +x ./create-networks.sh
  ./create-networks.sh

else
  echo "==> [${COMPONENT}] No compose.yaml, crontab, or create-networks.sh found in ${COMPONENT_DIR} — files synced, nothing to apply."
fi

echo "==> [${COMPONENT}] Deploy complete."
