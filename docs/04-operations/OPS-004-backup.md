# OPS-004 — Backup

**Status:** Approved
**Version:** 2.0
**Last Updated:** 2026-08-18

## 1. Purpose

Run and verify encrypted production backups to Google Drive through rclone.

## 2. One-time Google Drive setup

On the production server as `deploy`:

1. Install/provision rclone (bootstrap installs it, or install it using the
   official rclone method on an already-running server).
2. Authenticate headlessly and create a remote named exactly as
   `RCLONE_REMOTE`:

   ```bash
   rclone config
   rclone listremotes
   rclone lsd gdrive-backup:
   ```

   For a headless OAuth setup, start `rclone config` on the server and follow
   its browser URL flow, or use `rclone authorize` on a trusted workstation and
   paste the authorization result when prompted. Never commit or paste the
   token into this repository.
3. Put the config at `/home/deploy/.config/rclone/rclone.conf`, owned by
   `deploy`, mode `600`.
4. Copy `infrastructure/backup/backup.env.example` to
   `/srv/platform/backup/backup.env`, set the remote/base/config paths, and
   chmod it `600`. Do not put a token or password in it.
5. Provision `/srv/platform/backup/backup.key` out-of-band, owned by `deploy`,
   mode `600`, and store a separate offline recovery copy.
6. Run the read-only preflight:

   ```bash
   /srv/platform/backup/backup-doctor.sh
   ```

7. Run a manual backup and confirm the object exists in Drive before relying
   on cron.

The Google Drive root is not deleted or synchronized by this design.

## 3. Scheduled and manual execution

Cron runs at 03:00 UTC. Sunday adds the same archive to `weekly`; day 1 adds it
to `monthly`. Retention then keeps newest 14/8/6 per application and tier.

```bash
/srv/platform/backup/run-backup.sh
/srv/platform/backup/run-backup.sh invoice-api
```

Each valid application must have a lowercase kebab-case directory containing
`compose.yaml` and `.env`. Other `/srv/apps/*` directories are warned and
skipped. A valid application's database service is detected from Compose; if
`db` exists, it must be running and its `POSTGRES_USER`/`POSTGRES_DB` are read
inside the container. A failed or zero-byte dump fails that application backup.

The database dump is plain SQL (`db.sql`) and non-database persistent volume
data is copied while excluding `/volumes/db-data/`. Platform state is archived
under the `platform` pseudo-application only when the documented paths exist.

## 4. Verification

```bash
rclone --config /home/deploy/.config/rclone/rclone.conf listremotes
rclone --config /home/deploy/.config/rclone/rclone.conf lsd gdrive-backup:
rclone --config /home/deploy/.config/rclone/rclone.conf lsf \
  gdrive-backup:platform-production/daily/invoice-api
```

A successful script exit means every required `copyto` completed. A failed
upload is non-zero and leaves the encrypted local archive for retry; it is not
reported as success. Plaintext staging is cleaned through a restrictive exit
trap. The next monthly maintenance window must perform a restore test, not
just list the remote object.

## 5. Failure handling

If the doctor fails, do not start the backup. If a run exits non-zero, inspect
`/var/log/platform/backup.log` and the encrypted archive in staging, correct
the dependency/network/disk issue, and retry. The `flock` lock prevents a
second run; an overlapping invocation exits `75` and leaves no stale lock
process.

## 6. References

- [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md)
- [ADR-0010 — Backup Strategy](../02-decisions/ADR-0010-backup-strategy.md)
- [OPS-005 — Restore](OPS-005-restore.md)
- [OPS-012 — Migrate VPS Provider](OPS-012-migrate-vps-provider.md)
