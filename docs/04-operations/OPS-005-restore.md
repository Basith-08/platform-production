# OPS-005 — Restore

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure restores data from a backup created by [OPS-004 — Backup](OPS-004-backup.md), either for a single application's data recovery or as part of [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md).

---

# 2. Preconditions

- Access to the offsite backup destination and its decryption key.
- The target application's containers are stopped (for a single-application restore) or the target server is provisioned (for a full disaster recovery restore, per [OPS-001](OPS-001-server-provisioning.md)).
- The specific backup archive to restore (by date) has been identified.

---

# 3. Procedure

## 3.1 Single-Application Restore

1. Stop the affected application's containers: `docker compose stop` inside `/srv/apps/<app-name>`, to avoid writes during restore.
2. Download and decrypt the target backup archive from the offsite destination into a temporary location.
3. For a PostgreSQL database: restore the dump with `pg_restore` (or `psql` for plain-text dumps) into the running database container, or recreate the volume from a full data restore if the dump format requires an empty target.
4. For MinIO/object storage: sync the archived data back into `/srv/apps/<app-name>/volumes/<volume-name>`.
5. For configuration: restore `.env` to `/srv/apps/<app-name>/.env`, setting mode `600` per [STD-005, Rule 6](../03-standards/STD-005-environment-variables.md#3-rules).
6. Start the application: `docker compose up -d`.

## 3.2 Full Disaster Recovery Restore

Executed as steps 6–7 of [ARCH-010, Section 5](../01-architecture/ARCH-010-disaster-recovery-architecture.md#5-full-server-recovery-sequence), after server provisioning ([OPS-001](OPS-001-server-provisioning.md)) and before bringing up platform services:

1. Download and decrypt the most recent full backup archive from the offsite destination.
2. Restore all `.env` files to their respective `/srv/apps/<app-name>/` and `/srv/platform/` locations.
3. Restore Traefik dynamic configuration to `/srv/platform/traefik/`.
4. For each application with a database or object storage volume, restore its data into `/srv/apps/<app-name>/volumes/` following Section 3.1, steps 3–4.
5. Proceed to bringing up platform services and applications per [ARCH-010, Section 5](../01-architecture/ARCH-010-disaster-recovery-architecture.md#5-full-server-recovery-sequence).

---

# 4. Verification

- The restored application starts and reports `healthy`.
- Data integrity spot-check: query a known record (single-application restore) or confirm every application is reachable via Uptime Kuma (full restore).
- Compare the restored data's timestamp against the expected RPO (see [ARCH-010, Section 3](../01-architecture/ARCH-010-disaster-recovery-architecture.md#3-recovery-objectives)) to confirm no unexpected data loss beyond the accepted RPO window.

---

# 5. Rollback / Failure Handling

If a restore fails or produces corrupted data, do not delete the downloaded backup archive — retry the restore from a clean temporary location first, since a failed restore attempt does not indicate the source archive itself is corrupt. If multiple recent archives fail to restore cleanly, escalate to [OPS-008 — Incident Response](OPS-008-incident-response.md) and attempt restoring from an older archive, accepting the wider RPO.

---

# 6. References

- [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md)
- [ARCH-010 — Disaster Recovery Architecture](../01-architecture/ARCH-010-disaster-recovery-architecture.md)
- [OPS-004 — Backup](OPS-004-backup.md)
- [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md)
