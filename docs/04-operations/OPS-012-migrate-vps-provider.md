# OPS-012 — Migrate VPS Provider

**Status:** Approved
**Version:** 1.1
**Last Updated:** 2026-08-20

This runbook is provider-agnostic. Keep the old VPS available until the new
VPS passes restore and cutover verification.

## 1. Prepare

1. Record the old VPS IP, application image SHAs, Compose state, DNS records,
   and external integrations.
2. Lower DNS TTL before the change window, ideally to 300 seconds.
3. On the old VPS run the doctor and a fresh full backup, then verify the
   object in Drive:

   ```bash
   /srv/platform/backup/backup-doctor.sh
   /srv/platform/backup/run-backup.sh
   rclone --config /home/deploy/.config/rclone/rclone.conf lsf gdrive-backup:platform-production/daily
   ```

4. Do not cancel, delete, or reimage the old VPS.

## 2. Provision the new VPS

1. Create a provider-neutral Ubuntu 24.04 VPS. Transfer the bootstrap bundle
   through the provider console or a trusted workstation, then follow
   [OPS-001](OPS-001-server-provisioning.md): run `provision`, test separate
   `admin`/`deploy` sessions, and only then run `harden`.
2. Provision the same rclone remote name, authenticate Google Drive, copy the
   config to `/home/deploy/.config/rclone/rclone.conf` mode `600`, and install
   a separate `backup.key` copy mode `600`.
3. Configure `/srv/platform/backup/backup.env`; run `backup-doctor.sh`.
4. Verify the new SSH host key out-of-band and update `PROD_KNOWN_HOSTS` only
   after comparing the fingerprint. Deploy platform components from GitHub Actions and applications at their
   immutable GHCR commit-SHA images.

## 3. Restore and test before cutover

1. Select and download/decrypt the Google Drive archives using
   [OPS-005 — Restore](OPS-005-restore.md).
2. Restore platform/application `.env` files and monitoring data.
3. Restore PostgreSQL from `db.sql` into fresh database containers. Restore
   non-database uploads/object-storage data, never `volumes/db-data`.
4. Test without public DNS changes using temporary local DNS, a hosts-file
   override, an isolated hostname, or direct health checks. Verify TLS/routing,
   login, known rows, uploads, jobs, monitoring, and webhooks.

## 4. Final synchronization and cutover

1. Schedule a short application write freeze.
2. Run a final backup on the old VPS after the freeze and confirm its exact
   object appears in Google Drive.
3. Restore that final archive on the new VPS and repeat critical smoke tests.
4. Change DNS to the new IP and monitor health/logs through propagation.

If no write freeze is possible, document the remaining RPO and use an
application-specific synchronization strategy; one archive cannot guarantee
zero lost writes during an active cutover.

## 5. Rollback

Revert DNS to the old IP if the new host fails validation. Stop/cordon new-host
writes to avoid split-brain data, diagnose, and repeat final synchronization
before another cutover. Do not destroy the old VPS until rollback is no longer
needed.

## 6. Verification checklist

- [ ] Docker/Compose/rclone/GPG/rsync and firewall/SSH hardening are ready.
- [ ] Journald is capped at 300 MB; `/var/log/platform` is writable and rotated.
- [ ] `backup-doctor.sh` returns 0 and Google Drive is readable.
- [ ] Platform state and application configuration are restored.
- [ ] Applications run the intended immutable image SHAs.
- [ ] Known database rows and non-database persistent data are present.
- [ ] Routing, TLS, login, jobs, webhooks, and monitoring pass.
- [ ] Final backup/restore completed after the write freeze.
- [ ] DNS points to the new IP and remains stable through propagation.

Keep the old VPS powered and recoverable for an agreed 24–72 hour observation
window (or one full business cycle). Only then take a final backup, revoke old
access, and cancel the old provider resource.

## 7. References

- [OPS-001 — Server Provisioning](OPS-001-server-provisioning.md)
- [OPS-004 — Backup](OPS-004-backup.md)
- [OPS-005 — Restore](OPS-005-restore.md)
- [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md)
