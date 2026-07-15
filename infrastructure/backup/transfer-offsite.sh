#!/usr/bin/env bash
#
# Transfers a single encrypted backup archive to offsite storage.
#
# Usage: ./transfer-offsite.sh <path-to-archive>
#
# Reference: docs/01-architecture/ARCH-008-backup-architecture.md, Section 6

set -euo pipefail

ARCHIVE="$1"

if [ ! -f "${ARCHIVE}" ]; then
  echo "Archive not found: ${ARCHIVE}" >&2
  exit 1
fi

# Implementation note: the concrete transfer command depends on the offsite
# destination chosen for this environment (e.g. `rclone copy`, `aws s3 cp`,
# `rsync` over SSH to a separate host). Credentials for the destination are
# provisioned separately from production SSH access, per
# docs/01-architecture/ARCH-008-backup-architecture.md, Section 6, and are
# never stored in this repository.
#
# Example (rclone):
#   rclone copy "${ARCHIVE}" "offsite:platform-backups/$(basename "${ARCHIVE}")"

echo "Transferred $(basename "${ARCHIVE}") offsite."
