#!/usr/bin/env bash
# Offline smoke test for transfer and retention. No network or real rclone is used.

set -euo pipefail

test_dir="$(mktemp -d)"
trap 'rm -rf -- "${test_dir}"' EXIT
bin_dir="${test_dir}/bin"
remote_dir="${test_dir}/remote"
mkdir -p "${bin_dir}" "${remote_dir}"

cat > "${bin_dir}/rclone" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = --config ]; then shift 2; fi
command_name="${1:-}"; shift
case "${command_name}" in
  listremotes) printf 'gdrive-backup:\n' ;;
  lsd) exit 0 ;;
  copyto)
    if [ "${MOCK_FAIL_COPY:-0}" = 1 ]; then exit 1; fi
    while [[ "${1:-}" == --* ]]; do
      case "$1" in --retries|--low-level-retries|--stats) shift 2 ;; *) shift ;; esac
    done
    source_file="$1"; destination="$2"
    relative="${destination#gdrive-backup:}"
    mkdir -p "${MOCK_REMOTE}/$(dirname -- "${relative}")"
    cp -- "${source_file}" "${MOCK_REMOTE}/${relative}"
    ;;
  lsf)
    dirs_only=0
    while [[ "${1:-}" == --* ]]; do
      case "$1" in
        --dirs-only) dirs_only=1; shift ;;
        --files-only) shift ;;
        --format|--separator) shift 2 ;;
        *) shift ;;
      esac
    done
    relative="${1#gdrive-backup:}"
    directory="${MOCK_REMOTE}/${relative}"
    if [ "${dirs_only}" -eq 1 ]; then
      find "${directory}" -mindepth 1 -maxdepth 1 -type d -printf '%f/\n'
    else
      for object in "${directory}"/*; do
        [ -f "${object}" ] || continue
        name="$(basename -- "${object}")"
        second="${name:24:2}"
        printf '2026-08-18T03:00:%sZ\t%s\n' "${second}" "${name}"
      done
    fi
    ;;
  deletefile)
    relative="${1#gdrive-backup:}"
    rm -- "${MOCK_REMOTE}/${relative}"
    ;;
  *) echo "unexpected mock rclone command: ${command_name}" >&2; exit 2 ;;
esac
MOCK
chmod +x "${bin_dir}/rclone"

cat > "${bin_dir}/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[ "${1:-}" = compose ] || exit 2
if printf '%s\n' "$*" | grep -q ' config --services'; then
  printf 'api\n'
elif printf '%s\n' "$*" | grep -q ' version'; then
  printf 'Docker Compose mock\n'
fi
MOCK
cat > "${bin_dir}/gpg" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
output=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|--output) output="$2"; shift 2 ;;
    --passphrase-file) shift 2 ;;
    *) shift ;;
  esac
done
cat > "${output}"
MOCK
chmod +x "${bin_dir}/docker" "${bin_dir}/gpg"

config="${test_dir}/rclone.conf"
key="${test_dir}/backup.key"
env_file="${test_dir}/backup.env"
archive="${test_dir}/invoice-api-20260818T030000Z.tar.gz.gpg"
printf '[mock]\n' > "${config}"
printf 'test-key\n' > "${key}"
printf 'encrypted-test\n' > "${archive}"
chmod 600 "${config}" "${key}"
cat > "${env_file}" <<EOF
RCLONE_REMOTE=gdrive-backup
RCLONE_BASE_PATH='platform production'
RCLONE_CONFIG=${config}
RCLONE_RETRIES=1
RCLONE_RETRY_DELAY_SECONDS=0
BACKUP_MIN_FREE_GB=0
EOF

export PATH="${bin_dir}:${PATH}"
export MOCK_REMOTE="${remote_dir}"
export BACKUP_ENV_FILE="${env_file}"
export BACKUP_KEY_FILE="${key}"

"${PWD}/infrastructure/backup/transfer-offsite.sh" "${archive}" invoice-api daily >/dev/null
[ -f "${remote_dir}/platform production/daily/invoice-api/$(basename -- "${archive}")" ]

if MOCK_FAIL_COPY=1 "${PWD}/infrastructure/backup/transfer-offsite.sh" "${archive}" invoice-api daily >"${test_dir}/failure.log" 2>&1; then
    echo "expected mocked upload failure" >&2
    exit 1
fi
if grep -q 'Upload succeeded' "${test_dir}/failure.log"; then
    echo "failed upload was reported as success" >&2
    exit 1
fi

runtime_dir="${test_dir}/runtime"
apps_dir="${test_dir}/apps"
staging_dir="${runtime_dir}/staging"
mkdir -p "${apps_dir}/invoice-api/volumes/db-data" "${apps_dir}/invoice-api/volumes/uploads" "${staging_dir}"
printf 'services:\n  api:\n    image: example/test\n' > "${apps_dir}/invoice-api/compose.yaml"
printf 'APP_SECRET=test-only\n' > "${apps_dir}/invoice-api/.env"
export BACKUP_RUNTIME_DIR="${runtime_dir}"
export BACKUP_ENV_FILE="${env_file}"
export BACKUP_KEY_FILE="${key}"
export APPS_DIR="${apps_dir}"
export STAGING_DIR="${staging_dir}"
export BACKUP_LOCK_FILE="${test_dir}/backup.lock"
"${PWD}/infrastructure/backup/backup-doctor.sh" >"${test_dir}/doctor.log"
grep -q 'Backup doctor: ready.' "${test_dir}/doctor.log"
"${PWD}/infrastructure/backup/run-backup.sh" invoice-api >/dev/null
uploaded_archive="$(find "${remote_dir}/platform production/daily/invoice-api" -name '*.tar.gz.gpg' -print -quit)"
[ -n "${uploaded_archive}" ]
if tar -tzf "${uploaded_archive}" | grep -q 'db-data'; then
    echo "PostgreSQL physical data was copied" >&2
    exit 1
fi
[ -z "$(find "${staging_dir}" -name '*.tar.gz.gpg' -print -quit)" ]

mkdir -p "${remote_dir}/platform production/daily/invoice-api"
for second in $(seq -w 1 15); do
    printf 'archive-%s\n' "${second}" > "${remote_dir}/platform production/daily/invoice-api/invoice-api-20260818T0300${second}Z.tar.gz.gpg"
done
"${PWD}/infrastructure/backup/prune-backups.sh" >/dev/null
[ "$(find "${remote_dir}/platform production/daily/invoice-api" -type f | wc -l)" -eq 14 ]
echo "backup rclone smoke tests passed"
