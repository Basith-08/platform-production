#!/usr/bin/env bash
# Shared configuration and validation helpers for the production backup jobs.

set -euo pipefail

BACKUP_RUNTIME_DIR="${BACKUP_RUNTIME_DIR:-/srv/platform/backup}"
BACKUP_ENV_FILE="${BACKUP_ENV_FILE:-${BACKUP_RUNTIME_DIR}/backup.env}"
BACKUP_KEY_FILE="${BACKUP_KEY_FILE:-${BACKUP_RUNTIME_DIR}/backup.key}"
STAGING_DIR="${STAGING_DIR:-${BACKUP_RUNTIME_DIR}/staging}"
APPS_DIR="${APPS_DIR:-/srv/apps}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
BACKUP_MIN_FREE_GB="${BACKUP_MIN_FREE_GB:-3}"
TELEGRAM_RETRIES="${TELEGRAM_RETRIES:-3}"
TELEGRAM_RETRY_DELAY_SECONDS="${TELEGRAM_RETRY_DELAY_SECONDS:-10}"
TELEGRAM_MAX_FILE_MB="${TELEGRAM_MAX_FILE_MB:-49}"
TELEGRAM_API_BASE="${TELEGRAM_API_BASE:-https://api.telegram.org}"

load_backup_config() {
  if [ ! -r "${BACKUP_ENV_FILE}" ]; then
    echo "Backup configuration not found: ${BACKUP_ENV_FILE}" >&2
    return 1
  fi

  # backup.env is an operator-owned shell-compatible dotenv file. It must
  # never contain tokens or passwords; rclone keeps those in its own config.
  # shellcheck disable=SC1090
  . "${BACKUP_ENV_FILE}"

  TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
  BACKUP_MIN_FREE_GB="${BACKUP_MIN_FREE_GB:-3}"
  TELEGRAM_RETRIES="${TELEGRAM_RETRIES:-3}"
  TELEGRAM_RETRY_DELAY_SECONDS="${TELEGRAM_RETRY_DELAY_SECONDS:-10}"
  TELEGRAM_MAX_FILE_MB="${TELEGRAM_MAX_FILE_MB:-49}"
  TELEGRAM_API_BASE="${TELEGRAM_API_BASE:-https://api.telegram.org}"
}

validate_integer() {
  local name="$1" value="$2"
  if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
    echo "${name} must be a non-negative integer: ${value}" >&2
    return 1
  fi
}

validate_app_name() {
  local app_name="$1"
  if ! [[ "${app_name}" =~ ^[a-z0-9]+([a-z0-9-]*[a-z0-9])?$ ]]; then
    echo "Invalid application name '${app_name}'; expected lowercase kebab-case." >&2
    return 1
  fi
}

validate_telegram_config() {
  validate_integer BACKUP_MIN_FREE_GB "${BACKUP_MIN_FREE_GB}"
  validate_integer TELEGRAM_RETRIES "${TELEGRAM_RETRIES}"
  validate_integer TELEGRAM_RETRY_DELAY_SECONDS "${TELEGRAM_RETRY_DELAY_SECONDS}"
  validate_integer TELEGRAM_MAX_FILE_MB "${TELEGRAM_MAX_FILE_MB}"

  [ "${TELEGRAM_RETRIES}" -gt 0 ] || {
    echo "TELEGRAM_RETRIES must be greater than zero." >&2
    return 1
  }
  [ "${TELEGRAM_MAX_FILE_MB}" -gt 0 ] || {
    echo "TELEGRAM_MAX_FILE_MB must be greater than zero." >&2
    return 1
  }
  [ -n "${TELEGRAM_BOT_TOKEN}" ] || {
    echo "TELEGRAM_BOT_TOKEN must not be empty." >&2
    return 1
  }
  [ -n "${TELEGRAM_CHAT_ID}" ] || {
    echo "TELEGRAM_CHAT_ID must not be empty." >&2
    return 1
  }
  [[ "${TELEGRAM_CHAT_ID}" =~ ^-?[0-9]+$ ]] || {
    echo "TELEGRAM_CHAT_ID must be a numeric Telegram chat ID." >&2
    return 1
  }
  [[ "${TELEGRAM_BOT_TOKEN}" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || {
    echo "TELEGRAM_BOT_TOKEN has an unexpected format." >&2
    return 1
  }
  case "${TELEGRAM_API_BASE}" in
    https://*) ;;
    *) echo "TELEGRAM_API_BASE must use HTTPS." >&2; return 1 ;;
  esac
}

validate_backup_config() {
  validate_telegram_config
  [ -s "${BACKUP_KEY_FILE}" ] || {
    echo "Backup encryption key is missing or empty: ${BACKUP_KEY_FILE}" >&2
    return 1
  }
  if find "${BACKUP_KEY_FILE}" -prune -perm /077 -print -quit | grep -q .; then
    echo "Backup encryption key must not be group/world accessible: ${BACKUP_KEY_FILE}" >&2
    return 1
  fi
}

validate_telegram_api() {
  local response
  response="$(curl --fail --silent --show-error --connect-timeout 10 --max-time 30 \
    "${TELEGRAM_API_BASE}/bot${TELEGRAM_BOT_TOKEN}/getMe")" || {
      echo "Telegram Bot API is not reachable." >&2
      return 1
    }
  grep -q '"ok":true' <<< "${response}" || {
    echo "Telegram Bot API rejected the bot token." >&2
    return 1
  }
}

validate_tier() {
  case "$1" in
    daily|weekly|monthly) return 0 ;;
    *) echo "Invalid backup tier: $1" >&2; return 1 ;;
  esac
}

free_bytes() {
  local path="$1" available
  available="$(LC_ALL=C df -B1 --output=avail "${path}" | tail -n 1 | tr -d '[:space:]')"
  [[ "${available}" =~ ^[0-9]+$ ]] || {
    echo "Could not determine free bytes for ${path}." >&2
    return 1
  }
  printf '%s\n' "${available}"
}

ensure_free_space() {
  local path="$1" available minimum
  available="$(free_bytes "${path}")"
  minimum=$((BACKUP_MIN_FREE_GB * 1000000000))
  if [ "${available}" -lt "${minimum}" ]; then
    echo "Insufficient free space on ${path}: ${available} bytes available, ${minimum} required." >&2
    return 1
  fi
}
