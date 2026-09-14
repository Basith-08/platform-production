#!/usr/bin/env bash
# Upload one encrypted archive to the configured Telegram chat.
# Usage: transfer-telegram.sh <archive> <app-name>

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/backup-common.sh"

ARCHIVE="${1:?Usage: transfer-telegram.sh <archive> <app-name>}"
APP_NAME="${2:?Usage: transfer-telegram.sh <archive> <app-name>}"

[ -f "${ARCHIVE}" ] || { echo "Archive not found: ${ARCHIVE}" >&2; exit 1; }
[ -s "${ARCHIVE}" ] || { echo "Archive is empty: ${ARCHIVE}" >&2; exit 1; }

load_backup_config
validate_backup_config
command -v curl >/dev/null 2>&1 || { echo "curl is not installed." >&2; exit 1; }
validate_telegram_api

size_bytes="$(stat -c '%s' "${ARCHIVE}")"
max_bytes=$((TELEGRAM_MAX_FILE_MB * 1000000))
if [ "${size_bytes}" -gt "${max_bytes}" ]; then
  echo "Archive exceeds configured Telegram upload limit: ${size_bytes} > ${max_bytes} bytes." >&2
  exit 1
fi

filename="$(basename -- "${ARCHIVE}")"
caption="🔐 Backup ${APP_NAME}
UTC: $(date -u '+%Y-%m-%d %H:%M:%S')
File: ${filename}"

attempt=1
while [ "${attempt}" -le "${TELEGRAM_RETRIES}" ]; do
  echo "Uploading ${filename} to Telegram (attempt ${attempt}/${TELEGRAM_RETRIES})..."

  if response="$(
    curl --fail --silent --show-error \
      --connect-timeout 15 \
      --max-time 900 \
      -X POST \
      "${TELEGRAM_API_BASE}/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
      -F "chat_id=${TELEGRAM_CHAT_ID}" \
      -F "document=@${ARCHIVE};type=application/octet-stream" \
      -F "caption=${caption}"
  )"; then
    if grep -q '"ok":true' <<< "${response}"; then
      echo "Telegram upload succeeded: ${filename}"
      exit 0
    fi
    echo "Telegram API returned an unsuccessful response." >&2
  else
    echo "Telegram upload request failed." >&2
  fi

  if [ "${attempt}" -lt "${TELEGRAM_RETRIES}" ]; then
    echo "Upload failed; retrying in ${TELEGRAM_RETRY_DELAY_SECONDS}s." >&2
    sleep "${TELEGRAM_RETRY_DELAY_SECONDS}"
  fi
  attempt=$((attempt + 1))
done

echo "Telegram upload failed after ${TELEGRAM_RETRIES} attempts: ${filename}" >&2
exit 1
