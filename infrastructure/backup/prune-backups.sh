#!/usr/bin/env bash
# Keep the newest exact backup objects per application and retention tier.

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/backup-common.sh"

DAILY_RETENTION=14
WEEKLY_RETENTION=8
MONTHLY_RETENTION=6

load_backup_config
validate_rclone_config
command -v rclone >/dev/null 2>&1 || { echo "rclone is not installed." >&2; exit 1; }
validate_rclone_remote

list_apps() {
  local tier entry app
  declare -A seen=()
  for tier in daily weekly monthly; do
    validate_tier "${tier}"
    while IFS= read -r entry; do
      app="${entry%/}"
      if validate_app_name "${app}" >/dev/null 2>&1 && [ -z "${seen[${app}]+x}" ]; then
        seen["${app}"]=1
        printf '%s\n' "${app}"
      fi
    done < <(rclone --config "${RCLONE_CONFIG}" lsf --dirs-only "${RCLONE_REMOTE}:${RCLONE_BASE_PATH}/${tier}" 2>/dev/null || true)
  done
}

prune_tier() {
  local app_name="$1" tier="$2" keep="$3" path entry object index=0
  local -a objects=()

  validate_remote_object_target "${app_name}" "${tier}"
  path="$(remote_tier_path "${tier}" "${app_name}")"

  # Format is <RFC3339 modtime><TAB><filename>; sorting by the timestamp
  # keeps the newest objects first without parsing locale-dependent output.
  local listing
  listing="$(rclone --config "${RCLONE_CONFIG}" lsf --files-only \
    --format "tp" --separator $'\t' "${path}" 2>/dev/null)" || {
    echo "Unable to list backup objects under ${path}." >&2
    return 1
  }
  if [ -n "${listing}" ]; then
    mapfile -t objects < <(sort -r <<< "${listing}")
  fi

  for entry in "${objects[@]}"; do
    object="${entry#*$'\t'}"
    [ "${object}" != "${entry}" ] || continue
    if ! [[ "${object}" =~ ^${app_name}-[0-9]{8}T[0-9]{6}Z\.tar\.gz\.gpg$ ]]; then
      echo "Skipping unexpected object in ${path}: ${object}" >&2
      continue
    fi
    if [ "${index}" -ge "${keep}" ]; then
      echo "Deleting old ${tier} backup: ${path}/${object}"
      rclone --config "${RCLONE_CONFIG}" deletefile "${path}/${object}"
    fi
    index=$((index + 1))
  done
}

echo "Pruning offsite backups: ${DAILY_RETENTION} daily / ${WEEKLY_RETENTION} weekly / ${MONTHLY_RETENTION} monthly."
while IFS= read -r app_name; do
  [ -n "${app_name}" ] || continue
  prune_tier "${app_name}" daily "${DAILY_RETENTION}"
  prune_tier "${app_name}" weekly "${WEEKLY_RETENTION}"
  prune_tier "${app_name}" monthly "${MONTHLY_RETENTION}"
done < <(list_apps)

echo "Prune complete."
