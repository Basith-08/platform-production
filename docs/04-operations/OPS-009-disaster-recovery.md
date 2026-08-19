# OPS-009 — Disaster Recovery

**Status:** Approved

**Version:** 1.1

**Owner:** Platform Team

**Last Updated:** 2026-08-20

---

# 1. Purpose

This procedure is the executable form of [ARCH-010 — Disaster Recovery Architecture](../01-architecture/ARCH-010-disaster-recovery-architecture.md), used when the production server is fully lost and must be rebuilt.

---

# 2. Preconditions

- Access to the `platform-production` repository and every application repository.
- Access to GHCR (to confirm the last known-good image tags per application).
- Access to Google Drive/rclone authentication and the separately stored GPG `backup.key`.
- The ability to provision a new server (VPS console access or equivalent) and update DNS.

---

# 3. Procedure

1. **Provision a new server.** Execute [OPS-001 — Server Provisioning](OPS-001-server-provisioning.md) in full, including the separate `admin`/`deploy` keys, verified `PROD_KNOWN_HOSTS`, and rclone/backup key provisioning.
2. **Restore configuration and data.** Execute [OPS-005 — Restore](OPS-005-restore.md) and follow its platform/full recovery sections.
3. **Deploy the platform.** Run `Deploy Platform` manually with no component input. The workflow deploys `networks` first, then the remaining selected components in parallel; run `platform-doctor.sh full` after runtime files are restored.
4. **Redeploy every application.** For each application, in an order that respects any known inter-application dependency:
   - Identify the last known-good commit SHA (from the application repository's `git log` on its deploy branch, or the most recent successful GitHub Actions run).
   - Confirm the corresponding image exists in GHCR.
   - Trigger the application workflow with the known-good SHA; it synchronizes the committed manifest, preserves `.env`/volumes, pulls the immutable image, and runs bounded health verification.
5. **Update DNS** if the new server has a different public IP than the lost server.
6. **Re-register every application** in Uptime Kuma if the monitoring configuration was not fully captured by the configuration restore in Step 2.
7. **Validate** every platform service and application per Section 4.

---

# 4. Verification

- `docker ps` on the new server lists every expected platform service and application container as `Up` and `healthy`.
- Uptime Kuma shows every monitor as "up."
- Beszel reports normal resource utilization.
- Spot-check application data integrity against the RPO target in [ARCH-010, Section 3](../01-architecture/ARCH-010-disaster-recovery-architecture.md#3-recovery-objectives) (24 hours) — confirm no more than one day of data loss for any restored database.
- Total elapsed time from incident declaration to full recovery is measured against the RTO target (4 hours) and recorded for the post-incident review.

---

# 5. Rollback / Failure Handling

There is no "rollback" from a disaster recovery in progress — if a specific step fails (e.g., restore of one application's data), isolate that application and continue recovering the rest of the platform, then return to the failed application once the broader platform is stable. Document any deviation from this procedure encountered during execution and update this document afterward if the deviation reveals a gap.

---

# 6. References

- [ARCH-010 — Disaster Recovery Architecture](../01-architecture/ARCH-010-disaster-recovery-architecture.md)
- [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md)
- [OPS-001 — Server Provisioning](OPS-001-server-provisioning.md)
- [OPS-005 — Restore](OPS-005-restore.md)
- [OPS-012 — Migrate VPS Provider](OPS-012-migrate-vps-provider.md)
- [OPS-008 — Incident Response](OPS-008-incident-response.md)
