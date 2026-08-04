#!/usr/bin/env bash
#
# Executes a backup run: dumps registered databases, syncs object storage,
# archives configuration, encrypts the result, and transfers it offsite.
#
# Usage:
#   ./run-backup.sh            # back up every registered application
#   ./run-backup.sh <app-name> # back up a single application
#
# Reference: docs/01-architecture/ARCH-008-backup-architecture.md
#            docs/04-operations/OPS-004-backup.md

set -euo pipefail

STAGING_DIR="/srv/platform/backup/staging"
APPS_DIR="/srv/apps"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TARGET="${1:-}"

mkdir -p "${STAGING_DIR}"

backup_app() {
  local app_name="$1"
  local app_dir="${APPS_DIR}/${app_name}"
  local app_staging="${STAGING_DIR}/${app_name}-${TIMESTAMP}"

  echo "Backing up ${app_name}..."
  mkdir -p "${app_staging}"

  # Database dump, if the application defines a 'db' service.
  if docker compose -f "${app_dir}/compose.yaml" --env-file "${app_dir}/.env" ps db >/dev/null 2>&1; then
    docker compose -f "${app_dir}/compose.yaml" --env-file "${app_dir}/.env" exec -T db \
      pg_dump -U "${POSTGRES_USER:-postgres}" "${POSTGRES_DB:-app}" \
      > "${app_staging}/db.sql"
  fi

  # Object storage / volume sync, if present.
  if [ -d "${app_dir}/volumes" ]; then
    rsync -a "${app_dir}/volumes/" "${app_staging}/volumes/"
  fi

  # Configuration.
  if [ -f "${app_dir}/.env" ]; then
    cp "${app_dir}/.env" "${app_staging}/.env"
  fi

  # Encrypt and stage for offsite transfer.
  tar -czf - -C "${STAGING_DIR}" "$(basename "${app_staging}")" \
    | gpg --batch --yes --symmetric --cipher-algo AES256 \
      --passphrase-file /srv/platform/backup/backup.key \
      -o "${app_staging}.tar.gz.gpg"

  rm -rf "${app_staging}"

  echo "Transferring ${app_name} backup offsite..."
  "$(dirname "$0")/transfer-offsite.sh" "${app_staging}.tar.gz.gpg"

  rm -f "${app_staging}.tar.gz.gpg"
  echo "Backup of ${app_name} complete."
}

if [ -n "${TARGET}" ]; then
  backup_app "${TARGET}"
else
  for app_dir in "${APPS_DIR}"/*/; do
    backup_app "$(basename "${app_dir}")"
  done
fi

"$(dirname "$0")/prune-backups.sh"

echo "Backup run complete."
