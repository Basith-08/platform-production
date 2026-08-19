#!/usr/bin/env bash
# Read-only host and platform readiness report.

set -uo pipefail

MODE="${1:-full}"
PLATFORM_ROOT="${PLATFORM_ROOT:-/srv/platform}"
APPS_ROOT="${APPS_ROOT:-/srv/apps}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"
ADMIN_USER="${ADMIN_USER:-admin}"
failures=0

case "${MODE}" in
  host|platform|full) ;;
  *) echo "Usage: platform-doctor.sh [host|platform|full]" >&2; exit 2 ;;
esac

pass() { printf '  %-34s PASS\n' "$1"; }
warn() { printf '  %-34s WARN\n' "$1"; }
skip() { printf '  %-34s SKIP\n' "$1"; }
fail() { printf '  %-34s FAIL\n' "$1"; failures=$((failures + 1)); }

check_command() {
  local label="$1" command_name="$2"
  if command -v "${command_name}" >/dev/null 2>&1; then pass "${label}"; else fail "${label} (${command_name} missing)"; fi
}

check_os() {
  local pretty='unknown' architecture='unknown' os_id='' os_version=''
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    pretty="${PRETTY_NAME:-unknown}"
    os_id="${ID:-}"
    os_version="${VERSION_ID:-}"
  fi
  architecture="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  if [ "${os_id}" != ubuntu ] || [ "${os_version}" != 24.04 ]; then
    fail "${pretty}"; return
  fi
  pass "Ubuntu ${os_version} LTS"
  if [ "${architecture}" = amd64 ]; then pass "${architecture}"; else fail "${architecture} (expected amd64)"; fi
  if [ -n "$(hostname 2>/dev/null)" ]; then pass "hostname $(hostname)"; else fail "hostname"; fi
}

check_user() {
  local user="$1"
  if id -u "${user}" >/dev/null 2>&1; then pass "${user} user"; else fail "${user} user"; fi
  if id -u "${user}" >/dev/null 2>&1; then
    if [ "$(id -u)" -ne 0 ] && [ "${user}" != "$(id -un)" ]; then
      skip "${user} authorized_keys (permission denied)"
    elif [ -s "/home/${user}/.ssh/authorized_keys" ]; then
      pass "${user} authorized_keys"
    else
      fail "${user} authorized_keys"
    fi
  fi
}

check_host() {
  echo "Host"
  check_os
  echo "Users"
  check_user "${ADMIN_USER}"
  check_user "${DEPLOY_USER}"
  if id -nG "${DEPLOY_USER}" 2>/dev/null | tr ' ' '\n' | grep -qx sudo; then
    fail "deploy general sudo (unexpected)"
  else
    pass "deploy general sudo (absent)"
  fi
  if id -nG "${DEPLOY_USER}" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    pass "deploy Docker group"
  else
    fail "deploy Docker group"
  fi

  echo "Runtime"
  check_command Docker docker
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then pass "Docker Compose"; else fail "Docker Compose"; fi
  check_command rclone rclone
  check_command cron cron

  echo "Security"
  if [ "$(id -u)" -ne 0 ]; then
    skip "UFW active (root required)"
  elif command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -q '^Status: active'; then pass "UFW active"; else fail "UFW active"; fi
  else
    fail "UFW active (ufw missing)"
  fi
  if command -v sshd >/dev/null 2>&1; then
    if sshd_config="$(sshd -T 2>/dev/null)"; then
      if grep -qx 'permitrootlogin no' <<< "${sshd_config}"; then pass "root SSH disabled"; else fail "root SSH disabled"; fi
      if grep -qx 'passwordauthentication no' <<< "${sshd_config}"; then pass "password authentication off"; else fail "password authentication off"; fi
    else
      skip "effective SSH configuration (permission denied)"
    fi
  else
    skip "effective SSH configuration (sshd missing)"
  fi

  echo "Filesystem"
  if [ -d "${PLATFORM_ROOT}" ]; then pass "${PLATFORM_ROOT}"; else fail "${PLATFORM_ROOT}"; fi
  if [ -d "${APPS_ROOT}" ]; then pass "${APPS_ROOT}"; else fail "${APPS_ROOT}"; fi
  if [ -d "${PLATFORM_ROOT}" ] && [ "$(stat -c %U "${PLATFORM_ROOT}" 2>/dev/null)" = "${DEPLOY_USER}" ]; then
    pass "platform ownership"
  elif [ -d "${PLATFORM_ROOT}" ]; then
    warn "platform ownership"
  else
    skip "platform ownership"
  fi
  if [ -d "${APPS_ROOT}" ] && [ "$(stat -c %U "${APPS_ROOT}" 2>/dev/null)" = "${DEPLOY_USER}" ]; then
    pass "apps ownership"
  elif [ -d "${APPS_ROOT}" ]; then
    warn "apps ownership"
  else
    skip "apps ownership"
  fi

  echo "Host services"
  if [ "$(id -u)" -ne 0 ]; then
    skip "cron active (root required)"
  elif systemctl is-active --quiet cron 2>/dev/null; then
    pass "cron active"
  else
    warn "cron active"
  fi
  if [ -f /etc/systemd/journald.conf.d/size-limit.conf ]; then pass "journald size configuration"; else warn "journald size configuration"; fi
  if [ -f /etc/logrotate.d/platform ]; then pass "platform logrotate"; else warn "platform logrotate"; fi
}

check_network() {
  local network="$1"
  if ! command -v docker >/dev/null 2>&1; then skip "network ${network} (Docker unavailable)"; return; fi
  if docker network inspect "${network}" >/dev/null 2>&1; then pass "network ${network}"; else warn "network ${network} (not deployed)"; fi
}

check_runtime_file() {
  local label="$1" path="$2"
  if [ -s "${path}" ]; then pass "${label}"; else warn "${label} (not configured)"; fi
}

check_component() {
  local component="$1" dir services status
  dir="${PLATFORM_ROOT}/${component}"
  if [ ! -d "${dir}" ]; then warn "${component} directory (not prepared)"; return; fi
  pass "${component} directory"
  if [ -f "${dir}/compose.yaml" ]; then
    pass "${component} compose manifest"
    case "${component}" in
      traefik) check_runtime_file "traefik runtime env" "${dir}/.env" ;;
      monitoring) check_runtime_file "monitoring runtime env" "${dir}/.env" ;;
    esac
    if command -v docker >/dev/null 2>&1 && (cd "${dir}" && docker compose config --services >/dev/null 2>&1); then
      services="$(cd "${dir}" && docker compose config --services 2>/dev/null)"
      if [ -z "${services}" ]; then
        warn "${component} containers (profiles disabled)"
      else
        status="$(cd "${dir}" && docker compose ps --format '{{.Service}} {{.State}}' 2>/dev/null || true)"
        if [ -n "${status}" ]; then pass "${component} container state"; else warn "${component} containers (not running)"; fi
      fi
    else
      skip "${component} container state (Compose unavailable/config missing)"
    fi
  elif [ -f "${dir}/crontab" ]; then
    pass "${component} schedule"
    if crontab -l 2>/dev/null | grep -q "BEGIN platform:${component}"; then pass "${component} cron installed"; else warn "${component} cron (not installed)"; fi
  elif [ -f "${dir}/create-networks.sh" ]; then
    pass "${component} network helper"
  else
    warn "${component} manifest (not present)"
  fi
  if [ "${component}" = backup ]; then
    check_runtime_file "backup.env" "${dir}/backup.env"
    check_runtime_file "backup.key" "${dir}/backup.key"
    check_runtime_file "rclone config" "/home/${DEPLOY_USER}/.config/rclone/rclone.conf"
  fi
}

check_platform() {
  echo "Networks"
  check_network edge
  check_network platform-internal
  echo "Platform components"
  check_component traefik
  check_component monitoring
  check_component backup
  check_component maintenance
  check_component networks
}

echo "Platform Doctor"
echo "==============="
case "${MODE}" in
  host) check_host ;;
  platform) check_platform ;;
  full) check_host; check_platform ;;
esac

echo
if [ "${failures}" -eq 0 ]; then
  case "${MODE}" in
    host) echo "Overall: HOST READY" ;;
    platform) echo "Overall: PLATFORM CHECK COMPLETE" ;;
    full) echo "Overall: HOST READY (warnings may indicate undeployed optional state)" ;;
  esac
else
  echo "Overall: NOT READY (${failures} failure(s))"
fi
exit "${failures}"
