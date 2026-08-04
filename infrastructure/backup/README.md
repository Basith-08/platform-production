# infrastructure/backup/

Backup job scripts implementing [ARCH-008 — Backup Architecture](../../docs/01-architecture/ARCH-008-backup-architecture.md) and [ADR-0010 — Backup Strategy](../../docs/02-decisions/ADR-0010-backup-strategy.md).

## Layout

- `run-backup.sh` — dumps registered databases, syncs volumes, archives configuration, encrypts, and transfers offsite for one or every application.
- `transfer-offsite.sh` — the single place the offsite destination and its transfer command are configured.
- `prune-backups.sh` — enforces the retention policy (14 daily / 8 weekly / 6 monthly) at the offsite destination.
- `crontab` — the schedule installed on the production server during [OPS-001 — Server Provisioning](../../docs/04-operations/OPS-001-server-provisioning.md).

## Deploy

`crontab` and the `.sh` scripts above are synced to `/srv/platform/backup/` and the `crontab` file is (re-)installed for the deploy user automatically whenever this directory changes on `main` — see [`.github/workflows/deploy-platform.yml`](../../.github/workflows/deploy-platform.yml) and [OPS-011 — Deploy Platform Service](../../docs/04-operations/OPS-011-deploy-platform-service.md). There is no long-running container to health-check for this component; a successful sync plus `crontab -l` on the server is the verification.

## Operating

Routine execution is automatic via the installed `crontab`. Manual/on-demand execution and verification procedures are documented in [OPS-004 — Backup](../../docs/04-operations/OPS-004-backup.md). Restore procedures are documented in [OPS-005 — Restore](../../docs/04-operations/OPS-005-restore.md).

## Encryption Key

`run-backup.sh` reads a symmetric encryption passphrase from `/srv/platform/backup/backup.key`, which is provisioned out-of-band during server setup and is never committed to this repository, per [STD-005 — Environment Variables](../../docs/03-standards/STD-005-environment-variables.md).
