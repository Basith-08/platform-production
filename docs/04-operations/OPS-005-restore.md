# OPS-005 — Restore

**Status:** Approved
**Version:** 2.0
**Last Updated:** 2026-08-18

## 1. Preconditions

- A provisioned target server/non-production host.
- The separate GPG `backup.key` copy and rclone config/authentication.
- A selected exact object under `daily`, `weekly`, or `monthly`.
- Application `.env`/platform configuration is restored before Compose starts.

## 2. Download and decrypt

Run as `deploy` in a restrictive temporary directory. Replace placeholders;
do not put secrets in shell history or logs.

```bash
restore_dir="$(mktemp -d)"
chmod 700 "${restore_dir}"
rclone --config /home/deploy/.config/rclone/rclone.conf copyto \
  "gdrive-backup:platform-production/daily/invoice-api/invoice-api-<timestamp>.tar.gz.gpg" \
  "${restore_dir}/backup.tar.gz.gpg"
gpg --batch --decrypt --passphrase-file /srv/platform/backup/backup.key \
  --output "${restore_dir}/backup.tar.gz" "${restore_dir}/backup.tar.gz.gpg"
tar -xzf "${restore_dir}/backup.tar.gz" -C "${restore_dir}"
```

Use `find "${restore_dir}" -maxdepth 2 -type f` to inspect the archive. Keep
the decrypted directory local only for the restore and remove it securely
after verification.

## 3. Single application restore

1. Stop the target application's containers and take a copy of its current
   target state if this is not a clean disaster-recovery host.
2. Copy the archive's `.env` to `/srv/apps/<app-name>/.env`, mode `600`, and
   copy `compose.yaml` from the application repository/Git deployment.
3. Recreate the application database container without removing its volume:

   ```bash
   cd /srv/apps/<app-name>
   docker compose --env-file .env up -d db
   docker compose --env-file .env exec -T db sh -lc \
     'psql -U "$POSTGRES_USER" "$POSTGRES_DB"' < "${restore_dir}/<app>-<timestamp>/db.sql"
   ```

   The dump is plain SQL. Do not copy or restore `volumes/db-data`; it is
   deliberately excluded because PostgreSQL recovery uses the logical dump.
4. Restore non-database data with an exact source directory, for example:

   ```bash
   rsync -a "${restore_dir}/<app>-<timestamp>/volumes/" \
     /srv/apps/<app-name>/volumes/
   ```

5. Start and verify:

   ```bash
   docker compose --env-file .env up -d
   docker compose ps
   ```

## 4. Platform state restore

Before deploying/running platform services, restore any present files from the
`platform-<timestamp>` archive:

- `traefik/.env` -> `/srv/platform/traefik/.env`, mode `600`.
- `monitoring/.env` -> `/srv/platform/monitoring/.env`, mode `600`.
- `monitoring/beszel-data/` and `monitoring/kuma-data/` -> their matching
  `/srv/platform/monitoring/` paths.

Traefik ACME certificates are intentionally not restored; they are
regenerable after DNS/credentials are correct. Do not restore anything into
`/srv/platform/backup/` from the archive: its key/configuration are
provisioned separately.

## 5. Full disaster recovery

Follow [OPS-012 — Migrate VPS Provider](OPS-012-migrate-vps-provider.md) for
the ordered old-server/new-server cutover. Deploy infrastructure from Git,
deploy immutable application images from GHCR, restore platform/application
state, then test before DNS cutover.

## 6. Non-production restore test

Use a disposable Ubuntu/Docker host with an isolated hostname/network and a
copy of the production `.env` whose external endpoints/credentials have been
replaced with test values. Download/decrypt into `mktemp -d`, then restore the
database dump into a Compose project named `restore-test` and restore uploads
into a temporary `/srv/apps/restore-test/volumes` path. Never point the test at
production DNS, production databases, or production object-storage endpoints.
Verify a known row, expected upload, and application health; then stop/remove
the test project and delete the decrypted directory. Do not run retention or
delete commands against the production remote during this test.

## 7. References

- [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md)
- [OPS-004 — Backup](OPS-004-backup.md)
- [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md)
- [OPS-012 — Migrate VPS Provider](OPS-012-migrate-vps-provider.md)
