# OPS-010 — Maintenance

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure defines the platform's recurring maintenance cadence: the routine checks and drills that keep the guarantees made elsewhere in this documentation (backup restorability, disaster recovery readiness, resource headroom) actually true over time, rather than assumed.

---

# 2. Preconditions

- Access to the production server, Beszel, Uptime Kuma, and the offsite backup destination.

---

# 3. Procedure

## 3.1 Maintenance Cadence

| Task | Frequency | Reference |
|---|---|---|
| Review Beszel resource trends (disk, memory headroom) | Weekly | [OPS-007, Section 3.2](OPS-007-monitoring.md#32-routine-resource-check-beszel) |
| Review Uptime Kuma monitor list for staleness (decommissioned apps still monitored, new apps missing) | Weekly | [OPS-007, Section 3.1](OPS-007-monitoring.md#31-registering-a-new-application-in-uptime-kuma) |
| Restore-test a backup archive against a non-production target | Monthly | [OPS-005 — Restore](OPS-005-restore.md) |
| Full disaster recovery drill (stand up a parallel server from backups) | Quarterly | [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md) |
| Review and apply pending Docker Engine / platform-service image updates | Monthly | [OPS-006 — Docker Upgrade](OPS-006-docker-upgrade.md) |
| Review OS security patch status | Weekly (automated patching per [OPS-001](OPS-001-server-provisioning.md); manual review monthly) | [ARCH-007, Section 5](../01-architecture/ARCH-007-security-architecture.md#5-host-hardening-baseline) |
| Review `docs/05-roadmap/technical-debt.md` for items resolved or newly discovered | Monthly | [ROADMAP — Technical Debt](../05-roadmap/technical-debt.md) |

## 3.2 Maintenance Window Announcement

For any maintenance task expected to cause visible downtime (e.g., [OPS-006 — Docker Upgrade](OPS-006-docker-upgrade.md)):

1. Schedule the window at a low-traffic time.
2. Notify affected application owners in advance, per the ownership boundaries in [ARCH-002, Section 12](../01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries).
3. Execute the maintenance task.
4. Confirm all services recovered per that task's own verification section.

## 3.3 Decommissioning an Application

1. Confirm with the application owner that the application is genuinely being retired.
2. Remove DNS entries for the application's hostname.
3. Remove the application's Uptime Kuma monitor.
4. `docker compose down` inside `/srv/apps/<app-name>` (this stops and removes containers but not volumes by default, per [STD-008, Rule 5](../03-standards/STD-008-volume-standard.md#3-rules)).
5. Take a final backup of the application's volumes before deletion, retained for a documented grace period.
6. After the grace period, remove `/srv/apps/<app-name>` including its volumes, as a deliberate, separate, explicitly-confirmed action.

---

# 4. Verification

Each maintenance task's own verification criteria apply (see the referenced OPS document for that task). For the overall cadence, verification is simply: every row in the Section 3.1 table has a completed date within its stated frequency window.

---

# 5. Rollback / Failure Handling

If a scheduled maintenance task reveals a problem (e.g., a restore-test fails, a disaster recovery drill exceeds the RTO target), treat it as a finding, not a failure to hide: file it under [ROADMAP — Technical Debt](../05-roadmap/technical-debt.md) and prioritize a fix before the next scheduled occurrence of that task.

---

# 6. References

- [OPS-005 — Restore](OPS-005-restore.md)
- [OPS-006 — Docker Upgrade](OPS-006-docker-upgrade.md)
- [OPS-007 — Monitoring](OPS-007-monitoring.md)
- [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md)
- [ROADMAP — Technical Debt](../05-roadmap/technical-debt.md)
