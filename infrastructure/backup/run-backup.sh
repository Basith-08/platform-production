#!/usr/bin/env bash
# Create encrypted application/platform archives and upload them to Telegram.
# Usage: run-backup.sh [app-name]

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export GNUPGHOME="${BACKUP_GNUPGHOME:-${SCRIPT_DIR}/.gnupg}"
mkdir -p -- "${GNUPGHOME}"
chmod 700 "${GNUPGHOME}"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/backup-common.sh"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TARGET="${1:-}"
LOCK_FILE="${BACKUP_LOCK_FILE:-/run/lock/platform-backup/backup.lock}"
CURRENT_PLAINTEXT_DIR=""

cleanup_plaintext() {
  if [ -n "${CURRENT_PLAINTEXT_DIR}" ] && [ -d "${CURRENT_PLAINTEXT_DIR}" ]; then
    rm -rf -- "${CURRENT_PLAINTEXT_DIR}"
  fi
}
trap cleanup_plaintext EXIT

load_backup_config
validate_backup_config
command -v curl >/dev/null 2>&1 || { echo "curl is not installed." >&2; exit 1; }
validate_telegram_api
command -v docker >/dev/null 2>&1 || { echo "Docker is not installed." >&2; exit 1; }
docker compose version >/dev/null
command -v gpg >/dev/null 2>&1 || { echo "gpg is not installed." >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync is not installed." >&2; exit 1; }
command -v flock >/dev/null 2>&1 || { echo "flock is not installed." >&2; exit 1; }

mkdir -p -- "${STAGING_DIR}"
[ -d "${APPS_DIR}" ] || { echo "Applications directory not found: ${APPS_DIR}" >&2; exit 1; }
[ -w "${STAGING_DIR}" ] || { echo "Staging directory is not writable: ${STAGING_DIR}" >&2; exit 1; }
ensure_free_space "${STAGING_DIR}"

if ! mkdir -p -- "$(dirname -- "${LOCK_FILE}")" || ! exec 9>"${LOCK_FILE}"; then
  echo "Cannot create backup lock: ${LOCK_FILE}" >&2
  exit 1
fi
if ! flock -n 9; then
  echo "Backup already running; refusing to start a second process." >&2
  exit 75
fi

archive_and_upload() {
  local app_name="$1" source_dir="$2" archive archive_tmp base_name
  base_name="${app_name}-${TIMESTAMP}"
  archive="${STAGING_DIR}/${base_name}.tar.gz.gpg"
  archive_tmp="${archive}.tmp"

  ensure_free_space "${STAGING_DIR}"
  echo "Encrypting ${app_name} backup..."
  tar -czf - -C "${STAGING_DIR}" "$(basename -- "${source_dir}")" \
    | gpg --batch --yes --symmetric --cipher-algo AES256 \
      --passphrase-file "${BACKUP_KEY_FILE}" -o "${archive_tmp}"
  [ -s "${archive_tmp}" ] || { echo "Encrypted archive is empty: ${archive_tmp}" >&2; return 1; }
  mv -- "${archive_tmp}" "${archive}"
  rm -rf -- "${source_dir}"
  CURRENT_PLAINTEXT_DIR=""

  transfer_archive "${archive}" "${app_name}"
  rm -f -- "${archive}"
  echo "Backup of ${app_name} complete."
}

transfer_archive() {
  local archive="$1" app_name="$2"
  "${SCRIPT_DIR}/transfer-telegram.sh" "${archive}" "${app_name}"
}

backup_app() {
  local app_name="$1" app_dir="$2" app_staging services db_container db_name
  app_staging="${STAGING_DIR}/${app_name}-${TIMESTAMP}"

  echo "Backing up application ${app_name}..."
  mkdir -p -- "${app_staging}"
  CURRENT_PLAINTEXT_DIR="${app_staging}"

  services="$(docker compose -f "${app_dir}/compose.yaml" --env-file "${app_dir}/.env" config --services)"
  if grep -Fxq db <<< "${services}"; then
    db_container="$(docker compose -f "${app_dir}/compose.yaml" --env-file "${app_dir}/.env" ps -q db)"
    [ -n "${db_container}" ] || {
      echo "PostgreSQL service db exists but has no container for ${app_name}." >&2
      return 1
    }
    [ "$(docker inspect -f '{{.State.Running}}' "${db_container}")" = true ] || {
      echo "PostgreSQL container for ${app_name} is not running." >&2
      return 1
    }
    db_name="$(docker compose -f "${app_dir}/compose.yaml" --env-file "${app_dir}/.env" exec -T db \
      sh -lc 'printf "%s" "${POSTGRES_DB:-}"')"
    [ -n "${db_name}" ] || {
      echo "PostgreSQL container for ${app_name} has no POSTGRES_DB." >&2
      return 1
    }
    echo "Dumping PostgreSQL database ${db_name} for ${app_name}..."
    if ! docker compose -f "${app_dir}/compose.yaml" --env-file "${app_dir}/.env" exec -T db \
      sh -lc 'test -n "${POSTGRES_USER:-}" && test -n "${POSTGRES_DB:-}" && pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
      > "${app_staging}/db.sql"; then
      echo "PostgreSQL dump failed for ${app_name}; application backup aborted." >&2
      return 1
    fi
    [ -s "${app_staging}/db.sql" ] || {
      echo "PostgreSQL dump is zero-byte for ${app_name}; application backup aborted." >&2
      return 1
    }
  fi

  if [ -d "${app_dir}/volumes" ]; then
    echo "Copying non-database persistent volumes for ${app_name}..."
    mkdir -p -- "${app_staging}/volumes"
    rsync -a --exclude='db-data/' "${app_dir}/volumes/" "${app_staging}/volumes/"
  fi

  cp -- "${app_dir}/.env" "${app_staging}/.env"
  archive_and_upload "${app_name}" "${app_staging}"
}

backup_platform() {
  local platform_staging="${STAGING_DIR}/platform-${TIMESTAMP}"
  echo "Backing up non-regenerable platform state..."
  mkdir -p -- "${platform_staging}/traefik" "${platform_staging}/monitoring"
  CURRENT_PLAINTEXT_DIR="${platform_staging}"

  [ -f /srv/platform/traefik/.env ] && cp -- /srv/platform/traefik/.env "${platform_staging}/traefik/.env"
  [ -f /srv/platform/monitoring/.env ] && cp -- /srv/platform/monitoring/.env "${platform_staging}/monitoring/.env"
  for data_dir in /srv/platform/monitoring/beszel-data /srv/platform/monitoring/kuma-data; do
    if [ -d "${data_dir}" ]; then
      rsync -a -- "${data_dir}/" "${platform_staging}/monitoring/$(basename -- "${data_dir}")/"
    fi
  done

  if find "${platform_staging}" -type f -print -quit | grep -q .; then
    archive_and_upload platform "${platform_staging}"
  else
    echo "No configured platform state exists; skipping platform archive."
    rm -rf -- "${platform_staging}"
    CURRENT_PLAINTEXT_DIR=""
  fi
}

validate_app_dir() {
  local app_name="$1" app_dir="$2"
  validate_app_name "${app_name}"
  [ -d "${app_dir}" ] || { echo "Skipping ${app_dir}: not a directory." >&2; return 1; }
  [ -f "${app_dir}/compose.yaml" ] || { echo "Skipping ${app_name}: compose.yaml is missing." >&2; return 1; }
  [ -f "${app_dir}/.env" ] || { echo "Skipping ${app_name}: .env is missing." >&2; return 1; }
}

if [ -n "${TARGET}" ]; then
  validate_app_name "${TARGET}"
  validate_app_dir "${TARGET}" "${APPS_DIR}/${TARGET}"
  backup_app "${TARGET}" "${APPS_DIR}/${TARGET}"
else
  found_app=0
  for app_dir in "${APPS_DIR}"/*; do
    [ -d "${app_dir}" ] || continue
    app_name="$(basename -- "${app_dir}")"
    if ! validate_app_dir "${app_name}" "${app_dir}"; then
      echo "Warning: skipped non-application directory ${app_dir}." >&2
      continue
    fi
    found_app=1
    backup_app "${app_name}" "${app_dir}"
  done
  [ "${found_app}" -eq 1 ] || echo "Warning: no valid applications found under ${APPS_DIR}." >&2
fi

backup_platform
echo "Backup run complete."
