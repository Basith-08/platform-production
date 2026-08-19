#!/usr/bin/env bash
# Apply one already-synced platform component on the production server.

set -Eeuo pipefail

COMPONENT="${1:-}"
STAGED_DIR=""
HEALTH_RETRIES="${HEALTH_RETRIES:-24}"
HEALTH_INTERVAL_SECONDS="${HEALTH_INTERVAL_SECONDS:-10}"

usage() { echo "Usage: deploy-component.sh <component> [--staged-dir PATH]" >&2; }

[ -n "${COMPONENT}" ] || { usage; exit 2; }
shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    --staged-dir) [ "$#" -ge 2 ] || { usage; exit 2; }; STAGED_DIR="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

COMPONENT_DIR="/srv/platform/${COMPONENT}"
[ -d "${COMPONENT_DIR}" ] || { echo "No such component directory: ${COMPONENT_DIR}" >&2; exit 1; }

RUNTIME_EXCLUDES=(
  --exclude='*.env'
  --exclude='certs/'
  --exclude='*-data/'
  --exclude='staging/'
  --exclude='backup.key'
  --exclude='rclone.conf'
  --exclude='dashboard-users.htpasswd'
)

cleanup() {
  if [ -n "${STAGED_DIR}" ] && [ -d "${STAGED_DIR}" ]; then
    rm -rf -- "${STAGED_DIR}"
  fi
}
trap cleanup EXIT

if [ -n "${STAGED_DIR}" ]; then
  [ -d "${STAGED_DIR}" ] || { echo "Staging directory does not exist: ${STAGED_DIR}" >&2; exit 1; }
  SOURCE_DIR="${STAGED_DIR}"
else
  SOURCE_DIR="${COMPONENT_DIR}"
fi

require_runtime_file() {
  local path="$1" example="$2"
  if [ ! -s "${path}" ]; then
    echo "ERROR: Missing required runtime file: ${path}" >&2
    echo "Create it from: ${example}" >&2
    echo "See: docs/04-operations/OPS-013-manual-configuration-inventory.md" >&2
    return 1
  fi
}

validate_runtime_configuration() {
  case "${COMPONENT}" in
    traefik) require_runtime_file "${COMPONENT_DIR}/.env" "infrastructure/traefik/.env.example" ;;
    monitoring) require_runtime_file "${COMPONENT_DIR}/.env" "infrastructure/monitoring/.env.example" ;;
    backup)
      require_runtime_file "${COMPONENT_DIR}/backup.env" "infrastructure/backup/backup.env.example"
      require_runtime_file "${COMPONENT_DIR}/backup.key" "out-of-band backup key"
      require_runtime_file "/home/deploy/.config/rclone/rclone.conf" "out-of-band rclone config"
      ;;
  esac
}

promote_staged_configuration() {
  [ "${SOURCE_DIR}" != "${COMPONENT_DIR}" ] || return 0
  # Validate the staged Compose file against the live runtime .env without
  # copying the secret into staging. The symlink is removed by cleanup().
  if [ -f "${SOURCE_DIR}/compose.yaml" ]; then
    if [ -f "${COMPONENT_DIR}/.env" ] && [ ! -e "${SOURCE_DIR}/.env" ]; then
      ln -s "${COMPONENT_DIR}/.env" "${SOURCE_DIR}/.env"
    fi
    (cd "${SOURCE_DIR}" && docker compose config -q)
    rm -f -- "${SOURCE_DIR}/.env"
  fi
  rsync -a --delete "${RUNTIME_EXCLUDES[@]}" "${SOURCE_DIR}/" "${COMPONENT_DIR}/"
}

container_status() {
  local service cid services
  services="$(docker compose config --services)"
  if [ -z "${services}" ]; then
    echo "__NO_ACTIVE_SERVICES__"
    return 0
  fi
  while IFS= read -r service; do
    [ -n "${service}" ] || continue
    cid="$(docker compose ps -q "${service}")"
    if [ -z "${cid}" ]; then
      echo "${service} missing"
    else
      docker inspect -f '{{.Name}} {{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${cid}"
    fi
  done <<< "${services}"
}

wait_for_healthy() {
  local attempt statuses unhealthy
  for attempt in $(seq 1 "${HEALTH_RETRIES}"); do
    statuses="$(container_status)"
    if [ "${statuses}" = "__NO_ACTIVE_SERVICES__" ]; then
      echo "[${COMPONENT}] No active Compose services; all profiles are disabled."
      return 0
    fi
    unhealthy="$(awk '$2!="healthy" && $2!="running" {print}' <<< "${statuses}")"
    if [ -z "${unhealthy}" ]; then
      echo "[${COMPONENT}] All containers healthy:"
      echo "${statuses}"
      return 0
    fi
    echo "[${COMPONENT}] waiting for healthy containers (${attempt}/${HEALTH_RETRIES}):"
    echo "${unhealthy}"
    sleep "${HEALTH_INTERVAL_SECONDS}"
  done
  echo "[${COMPONENT}] FAILED health check after $((HEALTH_RETRIES * HEALTH_INTERVAL_SECONDS))s" >&2
  docker compose ps >&2
  docker compose logs --tail=50 >&2
  return 1
}

cd "${COMPONENT_DIR}"
validate_runtime_configuration
promote_staged_configuration

if [ -f prepare.sh ]; then
  echo "[${COMPONENT}] Preparing persistent runtime directories"
  COMPONENT_DIR="${COMPONENT_DIR}" ./prepare.sh
fi

if [ -f compose.yaml ]; then
  echo "[${COMPONENT}] Validating Compose configuration"
  docker compose config -q
  if [ -z "$(docker compose config --services)" ]; then
    echo "[${COMPONENT}] No active Compose services; all profiles are disabled."
  else
    echo "[${COMPONENT}] Pulling images"
    docker compose pull
    echo "[${COMPONENT}] Applying"
    docker compose up -d --force-recreate --remove-orphans
    echo "[${COMPONENT}] Verifying health"
    wait_for_healthy
  fi
elif [ -f crontab ]; then
  echo "[${COMPONENT}] Installing crontab entries for $(whoami)"
  chmod +x ./*.sh
  current_crontab="$(mktemp)"
  merged_crontab="$(mktemp)"
  trap 'rm -f "${current_crontab}" "${merged_crontab}"; cleanup' EXIT
  crontab -l 2>/dev/null > "${current_crontab}" || true
  awk -v begin="# BEGIN platform:${COMPONENT}" -v end="# END platform:${COMPONENT}" -v component="${COMPONENT}" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    component == "backup" && index($0, "/srv/platform/backup/run-backup.sh") { next }
    !skip { print }
  ' "${current_crontab}" > "${merged_crontab}"
  {
    cat "${merged_crontab}"
    echo "# BEGIN platform:${COMPONENT}"
    cat crontab
    echo "# END platform:${COMPONENT}"
  } | crontab -
  echo "[${COMPONENT}] Installed schedule."
elif [ -f create-networks.sh ]; then
  echo "[${COMPONENT}] Ensuring shared networks exist"
  chmod +x ./create-networks.sh
  ./create-networks.sh
else
  echo "[${COMPONENT}] Files synced; no Compose, crontab, or network action is defined."
fi

echo "[${COMPONENT}] Deploy complete."
