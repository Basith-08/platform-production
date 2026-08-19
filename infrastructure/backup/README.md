# Production backup component

This component creates GPG-symmetric encrypted archives and uploads them to
Google Drive through `rclone`. It is deployed to `/srv/platform/backup/` and
runs as the `deploy` user's cron job.

## Runtime files

Provision these files out-of-band; none is committed:

- `/srv/platform/backup/backup.env`, copied from `backup.env.example`.
- `/srv/platform/backup/backup.key`, the GPG passphrase file, mode `600`.
- `/home/deploy/.config/rclone/rclone.conf`, mode `600`.

`backup.key` and the rclone credential must have separate secure recovery
copies. The encrypted archive deliberately does not contain either one.

## Remote layout

The configured `RCLONE_BASE_PATH` is used below; the default is
`platform-production`:

```text
<remote>:platform-production/daily/<app-name>/<app-name>-<UTC timestamp>.tar.gz.gpg
<remote>:platform-production/weekly/<app-name>/<same archive>.tar.gz.gpg
<remote>:platform-production/monthly/<app-name>/<same archive>.tar.gz.gpg
```

Every successful run uploads `daily`. Sunday runs also upload `weekly`, and
the first day of a month also uploads `monthly`. Retention keeps the newest
14/8/6 objects per application and tier, using exact-object `rclone deletefile`.

The pseudo-application `platform` contains only existing, non-regenerable
platform state: Traefik/monitoring `.env` files and Beszel/Uptime Kuma data.
Traefik ACME certificates, Docker images/cache, containers, writable layers,
`backup.key`, `backup.env`, and `rclone.conf` are excluded.

## Commands

```bash
/srv/platform/backup/backup-doctor.sh
/srv/platform/backup/run-backup.sh                 # all valid applications + platform state
/srv/platform/backup/run-backup.sh invoice-api     # one application
rclone --config /home/deploy/.config/rclone/rclone.conf listremotes
rclone --config /home/deploy/.config/rclone/rclone.conf lsd gdrive-backup:
rclone --config /home/deploy/.config/rclone/rclone.conf lsf \
  gdrive-backup:platform-production/daily/invoice-api
```

The doctor is read-only and must return `0` before the first manual run.
Backups are serialized with `flock`; a concurrent invocation exits `75`.
Local encrypted archives are removed only after every required remote upload
succeeds. A failed upload leaves the encrypted archive in staging for retry or
diagnosis; plaintext staging is removed by the exit trap.

See [OPS-004 — Backup](../../docs/04-operations/OPS-004-backup.md),
[OPS-005 — Restore](../../docs/04-operations/OPS-005-restore.md), and
[OPS-012 — Migrate VPS Provider](../../docs/04-operations/OPS-012-migrate-vps-provider.md).
