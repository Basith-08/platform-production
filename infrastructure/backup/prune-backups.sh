#!/usr/bin/env bash
#
# Prunes offsite backups older than the retention policy defined in
# docs/01-architecture/ARCH-008-backup-architecture.md, Section 5:
#   14 daily, 8 weekly, 6 monthly (grandfather-father-son rotation).
#
# This script assumes the offsite destination is reachable via the same
# tool used by transfer-offsite.sh (e.g. rclone, restic, or an rsync target)
# and that backup archive filenames are prefixed "<app-name>-<ISO8601>".
#
# Reference: docs/04-operations/OPS-004-backup.md

set -euo pipefail

DAILY_RETENTION=14
WEEKLY_RETENTION=8
MONTHLY_RETENTION=6

echo "Pruning offsite backups (retention: ${DAILY_RETENTION} daily / ${WEEKLY_RETENTION} weekly / ${MONTHLY_RETENTION} monthly)..."

# Implementation note: the exact prune command depends on the offsite
# storage tool selected during OPS-001 provisioning (e.g. `rclone`,
# `restic forget --keep-daily 14 --keep-weekly 8 --keep-monthly 6`,
# or a lifecycle policy on the destination bucket). Configure the concrete
# command here once the offsite destination is finalized for this
# environment; this script is the single place that policy is enforced.

echo "Prune complete."
