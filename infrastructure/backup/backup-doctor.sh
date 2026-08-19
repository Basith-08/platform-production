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
check_command rclone rclone

if [ -r "${BACKUP_ENV_FILE}" ]; then
  ok "backup.env (${BACKUP_ENV_FILE})"
  # shellcheck disable=SC1090
  . "${BACKUP_ENV_FILE}"
  RCLONE_REMOTE="${RCLONE_REMOTE:-}"
  RCLONE_BASE_PATH="${RCLONE_BASE_PATH:-}"
  RCLONE_CONFIG="${RCLONE_CONFIG:-/home/deploy/.config/rclone/rclone.conf}"
  BACKUP_MIN_FREE_GB="${BACKUP_MIN_FREE_GB:-3}"
else
  fail "backup.env (${BACKUP_ENV_FILE})"
fi

if [ -s "${BACKUP_KEY_FILE}" ] && ! find "${BACKUP_KEY_FILE}" -prune -perm /077 -print -quit | grep -q .; then
  ok "backup.key exists with restrictive permissions"
else
  fail "backup.key exists with restrictive permissions"
fi

if [ -r "${RCLONE_CONFIG}" ] && ! find "${RCLONE_CONFIG}" -prune -perm /077 -print -quit | grep -q .; then
  ok "rclone config exists with restrictive permissions"
else
  fail "rclone config exists with restrictive permissions (${RCLONE_CONFIG})"
fi

if command -v rclone >/dev/null 2>&1 && [ -r "${RCLONE_CONFIG}" ]; then
  if remotes="$(rclone --config "${RCLONE_CONFIG}" listremotes 2>/dev/null)" \
    && grep -Fxq "${RCLONE_REMOTE}:" <<< "${remotes}"; then
    ok "Configured rclone remote (${RCLONE_REMOTE})"
    if rclone --config "${RCLONE_CONFIG}" lsd "${RCLONE_REMOTE}:" >/dev/null 2>&1; then
      ok "Google Drive remote"
    else
      fail "Google Drive remote is not reachable"
    fi
  else
    fail "Configured rclone remote (${RCLONE_REMOTE})"
  fi
else
  fail "Configured rclone remote"
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
