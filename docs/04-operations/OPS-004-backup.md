# OPS-004 — Backup

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure executes and verifies a backup run, implementing [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md).

---

# 2. Preconditions

- Backup jobs are defined and scheduled under `infrastructure/backup/`, per [ARCH-003, Section 5](../01-architecture/ARCH-003-directory-structure.md#5-infrastructure-structure-infrastructure).
- Offsite backup destination credentials are provisioned and accessible to the backup job (not to application containers).
- Every application requiring backup has its volumes registered per [STD-008, Rule 4](../03-standards/STD-008-volume-standard.md#3-rules).

---

# 3. Procedure

## 3.1 Scheduled (Automatic) Backup

Scheduled backups run automatically via cron, orchestrated by `infrastructure/automation/`, and require no manual action under normal operation. This section documents what happens for verification purposes:

1. The backup job dumps each registered PostgreSQL database (`pg_dump`) into the local staging area (`/srv/platform/backup/staging`).
2. The backup job syncs each registered object storage (MinIO) volume into staging.
3. The backup job archives `.env` files and Traefik dynamic configuration into staging.
4. The backup job encrypts the staged archive.
5. The backup job transfers the encrypted archive to the offsite destination.
6. The backup job prunes offsite backups older than the retention window, per [ARCH-008, Section 5](../01-architecture/ARCH-008-backup-architecture.md#5-schedule-and-retention).
7. The backup job clears local staging after a confirmed successful offsite transfer.

## 3.2 Manual On-Demand Backup

Used before a risky operation (e.g., a schema migration, a major version upgrade):

1. SSH to the production server as the deploy user.
2. Run the backup job script directly: `infrastructure/backup/run-backup.sh <app-name>` (or the platform-wide variant with no argument to back up everything).
3. Confirm the job completes successfully (exit code `0` and a new archive present at the offsite destination).

---

# 4. Verification

- The offsite destination shows a new archive with today's timestamp.
- The backup job's log (viewable via `docker compose logs` for the backup service, or the script's own log output) shows no errors.
- Uptime Kuma or an equivalent scheduled-job check (per [ARCH-009 — Monitoring Architecture](../01-architecture/ARCH-009-monitoring-architecture.md)) reflects a successful last-run timestamp.

---

# 5. Rollback / Failure Handling

If a scheduled backup fails, local staging is retained (Step 7 does not run), so the next scheduled attempt has a chance to succeed without losing the prior successful backup at the offsite destination. If backups fail for more than one consecutive scheduled run, treat it as an incident per [OPS-008 — Incident Response](OPS-008-incident-response.md) — do not let RPO silently degrade.

---

# 6. References

- [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md)
- [ADR-0010 — Backup Strategy](../02-decisions/ADR-0010-backup-strategy.md)
- [STD-008 — Volume Standard](../03-standards/STD-008-volume-standard.md)
- [OPS-005 — Restore](OPS-005-restore.md)
