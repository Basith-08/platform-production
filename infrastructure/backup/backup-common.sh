#!/usr/bin/env bash
# Shared configuration and validation helpers for the production backup jobs.

set -euo pipefail

BACKUP_RUNTIME_DIR="${BACKUP_RUNTIME_DIR:-/srv/platform/backup}"
BACKUP_ENV_FILE="${BACKUP_ENV_FILE:-${BACKUP_RUNTIME_DIR}/backup.env}"
BACKUP_KEY_FILE="${BACKUP_KEY_FILE:-${BACKUP_RUNTIME_DIR}/backup.key}"
STAGING_DIR="${STAGING_DIR:-${BACKUP_RUNTIME_DIR}/staging}"
APPS_DIR="${APPS_DIR:-/srv/apps}"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"
RCLONE_BASE_PATH="${RCLONE_BASE_PATH:-}"
RCLONE_CONFIG="${RCLONE_CONFIG:-/home/deploy/.config/rclone/rclone.conf}"
BACKUP_MIN_FREE_GB="${BACKUP_MIN_FREE_GB:-3}"
RCLONE_RETRIES="${RCLONE_RETRIES:-3}"
RCLONE_RETRY_DELAY_SECONDS="${RCLONE_RETRY_DELAY_SECONDS:-10}"

load_backup_config() {
  if [ ! -r "${BACKUP_ENV_FILE}" ]; then
    echo "Backup configuration not found: ${BACKUP_ENV_FILE}" >&2
    return 1
  fi

  # backup.env is an operator-owned shell-compatible dotenv file. It must
  # never contain tokens or passwords; rclone keeps those in its own config.
  # shellcheck disable=SC1090
  . "${BACKUP_ENV_FILE}"

  RCLONE_REMOTE="${RCLONE_REMOTE:-}"
  RCLONE_BASE_PATH="${RCLONE_BASE_PATH:-}"
  RCLONE_CONFIG="${RCLONE_CONFIG:-/home/deploy/.config/rclone/rclone.conf}"
  BACKUP_MIN_FREE_GB="${BACKUP_MIN_FREE_GB:-3}"
  RCLONE_RETRIES="${RCLONE_RETRIES:-3}"
  RCLONE_RETRY_DELAY_SECONDS="${RCLONE_RETRY_DELAY_SECONDS:-10}"
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

validate_rclone_config() {
  validate_integer BACKUP_MIN_FREE_GB "${BACKUP_MIN_FREE_GB}"
  validate_integer RCLONE_RETRIES "${RCLONE_RETRIES}"
  validate_integer RCLONE_RETRY_DELAY_SECONDS "${RCLONE_RETRY_DELAY_SECONDS}"
  [ "${RCLONE_RETRIES}" -gt 0 ] || {
    echo "RCLONE_RETRIES must be greater than zero." >&2
    return 1
  }

  [ -n "${RCLONE_REMOTE}" ] || {
    echo "RCLONE_REMOTE must not be empty." >&2
    return 1
  }
  if ! [[ "${RCLONE_REMOTE}" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    echo "RCLONE_REMOTE contains unsupported characters: ${RCLONE_REMOTE}" >&2
    return 1
  fi

  [ -n "${RCLONE_BASE_PATH}" ] || {
    echo "RCLONE_BASE_PATH must not be empty." >&2
    return 1
  }
  case "${RCLONE_BASE_PATH}" in
    /*|*/|*//*|*:*|.|..|../*|*/../*|*/..)
      echo "RCLONE_BASE_PATH is not a safe remote-relative path: ${RCLONE_BASE_PATH}" >&2
      return 1
      ;;
  esac

  [ -r "${RCLONE_CONFIG}" ] || {
    echo "rclone config is not readable: ${RCLONE_CONFIG}" >&2
    return 1
  }
}

validate_backup_config() {
  validate_rclone_config
  [ -s "${BACKUP_KEY_FILE}" ] || {
    echo "Backup encryption key is missing or empty: ${BACKUP_KEY_FILE}" >&2
    return 1
  }
  if find "${BACKUP_KEY_FILE}" -prune -perm /077 -print -quit | grep -q .; then
    echo "Backup encryption key must not be group/world accessible: ${BACKUP_KEY_FILE}" >&2
    return 1
  fi
}

validate_rclone_remote() {
  local remotes
  remotes="$(rclone --config "${RCLONE_CONFIG}" listremotes)" || {
    echo "Unable to list rclone remotes using ${RCLONE_CONFIG}." >&2
    return 1
  }
  if ! grep -Fxq "${RCLONE_REMOTE}:" <<< "${remotes}"; then
    echo "Configured rclone remote is unavailable: ${RCLONE_REMOTE}" >&2
    echo "Available remotes: ${remotes//$'\n'/ }" >&2
    return 1
  fi
  rclone --config "${RCLONE_CONFIG}" lsd "${RCLONE_REMOTE}:" >/dev/null || {
    echo "Google Drive remote cannot be accessed: ${RCLONE_REMOTE}" >&2
    return 1
  }
}

validate_tier() {
  case "$1" in
    daily|weekly|monthly) return 0 ;;
    *) echo "Invalid backup tier: $1" >&2; return 1 ;;
  esac
}

validate_remote_object_target() {
  local app_name="$1" tier="$2"
  validate_app_name "${app_name}"
  validate_tier "${tier}"
  [ -n "${RCLONE_REMOTE}" ] || { echo "RCLONE_REMOTE is empty." >&2; return 1; }
  [ -n "${RCLONE_BASE_PATH}" ] || { echo "RCLONE_BASE_PATH is empty." >&2; return 1; }
}

remote_tier_path() {
  local tier="$1" app_name="$2"
  validate_remote_object_target "${app_name}" "${tier}"
  printf '%s:%s/%s/%s' "${RCLONE_REMOTE}" "${RCLONE_BASE_PATH}" "${tier}" "${app_name}"
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
