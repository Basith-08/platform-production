# ADR-0010 — Scheduled Encrypted Backups to Google Drive

**Status:** Accepted
**Version:** 2.0
**Owner:** Platform Team
**Last Updated:** 2026-08-18

## 1. Context

Git and GHCR can regenerate infrastructure and application images, but runtime
databases, uploads/object storage, monitoring state, and secrets cannot. A
20 GB VPS also cannot safely retain unlimited local copies. Provider snapshots
would couple recovery to the provider being replaced.

## 2. Decision

Use scheduled, local-streamed, AES-256 GPG-encrypted archives and upload them
with `rclone copyto` to Google Drive. The remote is configured out-of-band by
the operator. PostgreSQL is backed up only as a logical dump from the database
container; `db-data/` is excluded from volume rsync. Retention is newest
14 daily / 8 weekly / 6 monthly per application, with exact-file deletion.

Keep only non-regenerable platform state and application persistent data.
Exclude source, images/cache, containers, writable layers, ACME certificates,
and all backup credentials. A separate offline copy of `backup.key` and a
recoverable rclone authentication path are mandatory recovery dependencies.

## 3. Consequences

Positive: offsite/provider-independent recovery, bounded local disk usage,
immutable image redeployment, clear database restore semantics, and no remote
destructive sync. Negative: Google Drive authentication and the GPG key need
manual recovery provisioning; logical dumps require a running compatible
PostgreSQL service during restore; restore tests remain an operational duty.

## 4. Rejected alternatives

- Full disk/provider snapshots: provider-coupled and include regenerable data.
- `rclone sync`: can delete remote backups after local staging drift.
- Physical PostgreSQL volume copy: unsafe/inconsistent while the database runs.
- No automated backup: leaves RPO and recovery unverified.

## 5. References

- [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md)
- [OPS-004 — Backup](../04-operations/OPS-004-backup.md)
- [OPS-005 — Restore](../04-operations/OPS-005-restore.md)
- [OPS-012 — Migrate VPS Provider](../04-operations/OPS-012-migrate-vps-provider.md)
