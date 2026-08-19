# ARCH-008 — Backup Architecture

**Status:** Approved
**Version:** 2.0
**Owner:** Platform Team
**Last Updated:** 2026-08-18

## 1. Purpose and boundary

Production compute is disposable. Git is the infrastructure/configuration
source of truth, GHCR is the durable source for immutable application images,
and Google Drive is the offsite store for encrypted persistent runtime state.
Provider snapshots are not part of the recovery design.

## 2. Scope

| Scope | Included | Method |
|---|---|---|
| Application database | PostgreSQL service `db` | Logical `pg_dump` executed inside the running container |
| Application persistent data | Non-database directories under `/srv/apps/<app>/volumes` | `rsync`; root `db-data/` is excluded |
| Application config | `/srv/apps/<app>/.env` | Encrypted archive |
| Platform state | Existing `/srv/platform/traefik/.env`, `/srv/platform/monitoring/.env`, `beszel-data`, `kuma-data` | Encrypted `platform` archive |
| Regenerable state | Source, Docker images/cache, containers, writable layers, Traefik ACME certs | Not backed up |
| Backup credentials | `backup.key`, `backup.env`, rclone config/OAuth credentials | Never included in archive; provision separately |

The database physical directory is never copied while PostgreSQL is running.
The logical SQL dump is the only PostgreSQL backup representation. Volume
directories such as uploads/object storage remain included.

## 3. Flow and destination

```text
VPS -> restrictive staging -> tar.gz -> AES-256 GPG -> rclone copyto -> Google Drive
```

The archive is uploaded to:

```text
<remote>:<base>/daily/<app-name>/<archive>.tar.gz.gpg
<remote>:<base>/weekly/<app-name>/<archive>.tar.gz.gpg
<remote>:<base>/monthly/<app-name>/<archive>.tar.gz.gpg
```

The same immutable archive is copied to multiple tiers when applicable.
`rclone sync` is intentionally not used. Upload failure is non-zero and does
not remove the local encrypted archive; removal happens only after all required
`copyto` operations succeed.

## 4. Schedule, retention, and safety

- Daily at 03:00 UTC.
- Sunday: daily plus weekly.
- Calendar day 1: daily plus monthly.
- Keep newest 14 daily, 8 weekly, and 6 monthly objects per application.
- Retention lists only a validated tier/app path and deletes exact objects with
  `rclone deletefile`; it never targets a remote root.
- `flock` prevents overlapping runs. Low disk space (`BACKUP_MIN_FREE_GB`,
  default 3 GB) fails before archive creation.
- The doctor checks dependencies, key/config permissions, remote access,
  staging writability, application root, and free space.

## 5. Encryption and recovery dependencies

GPG symmetric AES-256 encryption remains the format. `/srv/platform/backup/backup.key`
must have a separate offline/secure copy: without it, `.gpg` archives cannot be
decrypted. Google Drive rclone credentials must likewise be re-provisioned or
re-authenticated on a replacement VPS; they are not stored in Git or inside
the archive.

## 6. Verification

Presence is not proof. Operators must list the object in Google Drive, decrypt
it with the offline key, inspect the tar contents, and perform a restore test
against a non-production target. See [OPS-004 — Backup](../04-operations/OPS-004-backup.md),
[OPS-005 — Restore](../04-operations/OPS-005-restore.md), and the provider-
agnostic [OPS-012 migration runbook](../04-operations/OPS-012-migrate-vps-provider.md).

## 7. References

- [ADR-0010 — Backup Strategy](../02-decisions/ADR-0010-backup-strategy.md)
- [OPS-004 — Backup](../04-operations/OPS-004-backup.md)
- [OPS-005 — Restore](../04-operations/OPS-005-restore.md)
- [OPS-009 — Disaster Recovery](../04-operations/OPS-009-disaster-recovery.md)
- [OPS-012 — Migrate VPS Provider](../04-operations/OPS-012-migrate-vps-provider.md)
