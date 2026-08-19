#!/usr/bin/env bash
# Upload one encrypted archive to an exact rclone object path.
# Usage: transfer-offsite.sh <archive> <app-name> <tier>

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/backup-common.sh"

ARCHIVE="${1:?Usage: transfer-offsite.sh <archive> <app-name> <tier>}"
APP_NAME="${2:?Usage: transfer-offsite.sh <archive> <app-name> <tier>}"
TIER="${3:?Usage: transfer-offsite.sh <archive> <app-name> <tier>}"

[ -f "${ARCHIVE}" ] || { echo "Archive not found: ${ARCHIVE}" >&2; exit 1; }
[ -s "${ARCHIVE}" ] || { echo "Archive is empty: ${ARCHIVE}" >&2; exit 1; }

load_backup_config
validate_rclone_config
validate_remote_object_target "${APP_NAME}" "${TIER}"
command -v rclone >/dev/null 2>&1 || { echo "rclone is not installed." >&2; exit 1; }
validate_rclone_remote

FILENAME="$(basename -- "${ARCHIVE}")"
DESTINATION="$(remote_tier_path "${TIER}" "${APP_NAME}")/${FILENAME}"

attempt=1
while [ "${attempt}" -le "${RCLONE_RETRIES}" ]; do
  echo "Uploading ${FILENAME} to ${DESTINATION} (attempt ${attempt}/${RCLONE_RETRIES})..."
  if rclone --config "${RCLONE_CONFIG}" copyto \
      --retries 1 --low-level-retries 3 --stats 0 \
      "${ARCHIVE}" "${DESTINATION}"; then
    echo "Upload succeeded: ${DESTINATION}"
    exit 0
  fi

  if [ "${attempt}" -lt "${RCLONE_RETRIES}" ]; then
    echo "Upload failed; retrying in ${RCLONE_RETRY_DELAY_SECONDS}s." >&2
    sleep "${RCLONE_RETRY_DELAY_SECONDS}"
  fi
  attempt=$((attempt + 1))
done

echo "Upload failed after ${RCLONE_RETRIES} attempts: ${DESTINATION}" >&2
exit 1
