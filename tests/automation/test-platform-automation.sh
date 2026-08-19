#!/usr/bin/env bash
# Offline behavioral tests for provisioning/deployment helpers.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$(mktemp -d -t platform-automation-test.XXXXXX)"
trap 'rm -rf -- "${test_dir}"' EXIT

assert_contains() {
  local needle="$1" file="$2"
  grep -Fqx "${needle}" "${file}" || {
    echo "Expected '${needle}' in ${file}." >&2
    exit 1
  }
}

if "${repo_root}/infrastructure/automation/bootstrap.sh" "${test_dir}/legacy.pub" >"${test_dir}/legacy.log" 2>&1; then
  echo "legacy bootstrap syntax unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'subcommand is required' "${test_dir}/legacy.log"

plan_output="${test_dir}/plan.output"
EVENT_NAME=workflow_dispatch MANUAL_COMPONENT=traefik GITHUB_OUTPUT="${plan_output}" \
  "${repo_root}/infrastructure/automation/detect-changed-components.sh" >/dev/null
assert_contains 'components=["traefik"]' "${plan_output}"
assert_contains 'non_network=["traefik"]' "${plan_output}"
assert_contains 'networks_selected=false' "${plan_output}"

EVENT_NAME=workflow_dispatch MANUAL_COMPONENT=networks GITHUB_OUTPUT="${plan_output}" \
  "${repo_root}/infrastructure/automation/detect-changed-components.sh" >/dev/null
assert_contains 'components=["networks"]' "${plan_output}"
assert_contains 'non_network=[]' "${plan_output}"
assert_contains 'networks_selected=true' "${plan_output}"

missing_before_output="${test_dir}/missing-before.output"
missing_before_log="${test_dir}/missing-before.log"
(
  cd "${repo_root}"
  EVENT_NAME=push \
    BEFORE_SHA=1111111111111111111111111111111111111111 \
    AFTER_SHA="$(git rev-parse HEAD)" \
    GITHUB_OUTPUT="${missing_before_output}" \
    "${repo_root}/infrastructure/automation/detect-changed-components.sh"
) >/dev/null 2>"${missing_before_log}"
assert_contains 'components=["backup","maintenance","monitoring","networks","traefik"]' "${missing_before_output}"
grep -q 'is unavailable in this checkout' "${missing_before_log}"

mock_bin="${test_dir}/bin"
install_root="${test_dir}/install"
mkdir -p "${mock_bin}" "${install_root}"
printf '%s\n' '#!/usr/bin/env bash' 'printf "rclone v1.75.0\n"' > "${test_dir}/rclone"
chmod +x "${test_dir}/rclone"
zip -q -j "${test_dir}/release.zip" "${test_dir}/rclone"
release_hash="$(sha256sum "${test_dir}/release.zip" | awk '{print $1}')"
cat > "${mock_bin}/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
output=''
url=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    http*) url="$1"; shift ;;
    *) shift ;;
  esac
done
if [[ "${url}" == */SHA256SUMS ]]; then
  printf '%s  rclone-v1.75.0-linux-amd64.zip\n' "${MOCK_RELEASE_HASH}" > "${output}"
else
  cp "${MOCK_RELEASE_ARCHIVE}" "${output}"
fi
MOCK
chmod +x "${mock_bin}/curl"

if MOCK_RELEASE_HASH="${release_hash}" MOCK_RELEASE_ARCHIVE="${test_dir}/release.zip" \
  RCLONE_INSTALL_DIR="${install_root}" PATH="${mock_bin}:${PATH}" \
  "${repo_root}/infrastructure/automation/install-rclone.sh" >"${test_dir}/rclone.log" 2>&1; then
  echo "checksum mismatch unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'Pinned checksum' "${test_dir}/rclone.log"
[ ! -e "${install_root}/rclone" ]

printf '%s\n' '#!/usr/bin/env bash' 'printf "rclone v1.75.0\n"' > "${install_root}/rclone"
chmod +x "${install_root}/rclone"
printf '%s\n' '#!/usr/bin/env bash' 'echo curl must not be called >&2; exit 99' > "${mock_bin}/curl"
chmod +x "${mock_bin}/curl"
RCLONE_INSTALL_DIR="${install_root}" PATH="${mock_bin}:${PATH}" \
  "${repo_root}/infrastructure/automation/install-rclone.sh" >/dev/null

mkdir -p "${test_dir}/platform/traefik" "${test_dir}/apps"
printf 'SECRET_VALUE=must-not-print\n' > "${test_dir}/platform/traefik/.env"
doctor_output="${test_dir}/doctor.log"
PLATFORM_ROOT="${test_dir}/platform" APPS_ROOT="${test_dir}/apps" \
  DEPLOY_USER="$(id -un)" ADMIN_USER="$(id -un)" \
  "${repo_root}/infrastructure/automation/platform-doctor.sh" platform >"${doctor_output}"
grep -q 'Platform Doctor' "${doctor_output}"
grep -q 'WARN' "${doctor_output}"
if grep -q 'SECRET_VALUE' "${doctor_output}"; then
  echo "doctor output leaked runtime secret" >&2
  exit 1
fi

echo "platform automation tests passed"
