#!/usr/bin/env bash
# Install the pinned rclone release for the supported Ubuntu host.
#
# The version and checksum are intentionally maintained here, in one place.
# Both the archive and SHA256SUMS are fetched from official rclone release
# locations; the GitHub release is preferred because downloads.rclone.org was
# observed to be unreliable during provisioning.

set -euo pipefail

RCLONE_VERSION="1.75.0"
RCLONE_ASSET="rclone-v${RCLONE_VERSION}-linux-amd64.zip"
RCLONE_SHA256="aa2804e08f48250e71009c727124b6341cd0288465804a9a09d14663cabafbaa"
RCLONE_INSTALL_DIR="${RCLONE_INSTALL_DIR:-/usr/local/bin}"
RCLONE_TARGET="${RCLONE_INSTALL_DIR}/rclone"

github_base="https://github.com/rclone/rclone/releases/download/v${RCLONE_VERSION}"
official_base="https://downloads.rclone.org/v${RCLONE_VERSION}"

curl_args=(
    --fail
    --location
    --silent
    --show-error
    --connect-timeout 15
    --max-time 300
    --retry 4
    --retry-delay 5
    --retry-all-errors
)

current_version() {
    [ -x "${RCLONE_TARGET}" ] || return 1
    "${RCLONE_TARGET}" version 2>/dev/null |
    awk '/^rclone v/ {
      sub(/^v/, "", $2)
      print $2
      exit
    }'
}

download_release_file() {
    local name="$1"
    local destination="$2"
    
    echo "Primary download: ${github_base}/${name}"
    
    if curl "${curl_args[@]}" \
    "${github_base}/${name}" \
    -o "${destination}"; then
        return 0
    fi
    
    echo "Primary download failed or timed out; trying official fallback." >&2
    
    curl "${curl_args[@]}" \
    "${official_base}/${name}" \
    -o "${destination}"
}

verify_archive() {
    local checksum_file="$1"
    local archive_dir="$2"
    local checksum_line
    
    checksum_line="$(
        awk \
        -v hash="${RCLONE_SHA256}" \
        -v name="${RCLONE_ASSET}" \
        '$1 == hash && ($2 == name || $2 == "*" name) {
        print
        exit
        }' \
        "${checksum_file}"
    )"
    
    [ -n "${checksum_line}" ] || {
        echo "Pinned checksum for ${RCLONE_ASSET} was not found in official SHA256SUMS." >&2
        return 1
    }
    
    (
        cd "${archive_dir}"
        printf '%s\n' "${checksum_line}" | sha256sum -c -
    )
}

install_rclone() {
    local temporary_dir
    local archive_dir
    local extract_dir
    local archive
    local checksum_file
    local installed
    local rclone_binary
    
    installed="$(current_version || true)"
    
    if [ "${installed}" = "${RCLONE_VERSION}" ]; then
        echo "rclone v${RCLONE_VERSION} already installed; skipping download."
        "${RCLONE_TARGET}" version
        return 0
    fi
    
    if [ -n "${installed}" ]; then
        echo "Replacing rclone v${installed} with pinned v${RCLONE_VERSION}."
    else
        echo "Installing pinned rclone v${RCLONE_VERSION}."
    fi
    
    temporary_dir="$(mktemp -d -t platform-rclone.XXXXXX)"
    trap 'rm -rf -- "${temporary_dir}"' RETURN
    
    archive_dir="${temporary_dir}/archive"
    extract_dir="${temporary_dir}/extract"
    
    mkdir -p \
    "${archive_dir}" \
    "${extract_dir}"
    
    archive="${archive_dir}/${RCLONE_ASSET}"
    checksum_file="${temporary_dir}/SHA256SUMS"
    
    download_release_file \
    "${RCLONE_ASSET}" \
    "${archive}"
    
    download_release_file \
    "SHA256SUMS" \
    "${checksum_file}"
    
    verify_archive \
    "${checksum_file}" \
    "${archive_dir}"
    
    echo "Checksum verified for ${RCLONE_ASSET}."
    
    unzip -q \
    "${archive}" \
    -d "${extract_dir}"
    
    # rclone release archives contain the binary inside a versioned
    # directory, for example:
    #
    # rclone-v1.75.0-linux-amd64/rclone
    #
    # Do not assume that the binary is directly under ${extract_dir}.
    rclone_binary="$(
        find "${extract_dir}" \
        -type f \
        -name "rclone" \
        -perm -u+x \
        -print \
        -quit
    )"
    
    [ -n "${rclone_binary}" ] || {
        echo "Release archive does not contain an executable rclone binary." >&2
        return 1
    }
    
    echo "Found rclone binary: ${rclone_binary}"
    
    install -d -m 0755 \
    "${RCLONE_INSTALL_DIR}"
    
    install -m 0755 \
    "${rclone_binary}" \
    "${RCLONE_TARGET}.tmp"
    
    mv -f -- \
    "${RCLONE_TARGET}.tmp" \
    "${RCLONE_TARGET}"
    
    echo "rclone v${RCLONE_VERSION} installed."
    
    "${RCLONE_TARGET}" version
}

install_rclone "$@"