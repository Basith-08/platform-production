#!/usr/bin/env bash
# Read-only readiness check for the production backup job.

set -u
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/backup-common.sh"

failures=0
ok() { printf '[OK] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; failures=$((failures + 1)); }

check_command() {
  local label="$1" command_name="$2"
  if command -v "${command_name}" >/dev/null 2>&1; then ok "${label}"; else fail "${label} (${command_name} missing)"; fi
}

check_command Docker docker
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  ok "Docker Compose"
else
  fail "Docker Compose"
fi
check_command GPG gpg
check_command rsync rsync
check_command curl curl
check_command Python3 python3

if [ -r "${BACKUP_ENV_FILE}" ]; then
  ok "backup.env (${BACKUP_ENV_FILE})"
  # shellcheck disable=SC1090
  . "${BACKUP_ENV_FILE}"
  TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
  BACKUP_MIN_FREE_GB="${BACKUP_MIN_FREE_GB:-3}"
  TELEGRAM_RETRIES="${TELEGRAM_RETRIES:-3}"
  TELEGRAM_RETRY_DELAY_SECONDS="${TELEGRAM_RETRY_DELAY_SECONDS:-10}"
  TELEGRAM_MAX_FILE_MB="${TELEGRAM_MAX_FILE_MB:-49}"
  TELEGRAM_API_BASE="${TELEGRAM_API_BASE:-https://api.telegram.org}"
else
  fail "backup.env (${BACKUP_ENV_FILE})"
fi

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]   && [[ "${TELEGRAM_CHAT_ID}" =~ ^-?[0-9]+$ ]]   && [[ "${TELEGRAM_API_BASE}" == https://* ]]; then
  ok "Telegram configuration"
else
  fail "Telegram configuration"
fi

if command -v curl >/dev/null 2>&1 && [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  if curl --fail --silent --show-error --connect-timeout 10 --max-time 30     "${TELEGRAM_API_BASE}/bot${TELEGRAM_BOT_TOKEN}/getMe" | grep -q '"ok":true'; then
    ok "Telegram Bot API"
  else
    fail "Telegram Bot API"
  fi
else
  fail "Telegram Bot API"
fi

if [ -n "${TELEGRAM_CHAT_ID:-}" ] && [[ "${TELEGRAM_CHAT_ID}" =~ ^-?[0-9]+$ ]]; then
  ok "Telegram chat ID format"
else
  fail "Telegram chat ID format"
fi

if [ -d "${STAGING_DIR}" ] && [ -w "${STAGING_DIR}" ]; then ok "Staging writable (${STAGING_DIR})"; else fail "Staging writable (${STAGING_DIR})"; fi
if [ -d "${APPS_DIR}" ]; then ok "Applications directory (${APPS_DIR})"; else fail "Applications directory (${APPS_DIR})"; fi

if [ -d "${STAGING_DIR}" ] && [[ "${BACKUP_MIN_FREE_GB:-}" =~ ^[0-9]+$ ]]; then
  available="$(free_bytes "${STAGING_DIR}" 2>/dev/null || true)"
  minimum=$((BACKUP_MIN_FREE_GB * 1000000000))
  if [ -n "${available}" ] && [ "${available}" -ge "${minimum}" ]; then
    ok "Disk free (${available} bytes available)"
  else
    fail "Disk free below configured threshold (${BACKUP_MIN_FREE_GB} GB)"
  fi
else
  fail "Disk free threshold configuration"
fi

if [ "${failures}" -eq 0 ]; then
  echo "Backup doctor: ready."
else
  echo "Backup doctor: not ready (${failures} failure(s))." >&2
fi
exit "${failures}"
