# ADR-0010 — Scheduled Encrypted Backups Scoped to Irreplaceable Data

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

Because production never stores source code ([ADR-0002](ADR-0002-git-source-of-truth.md)) and images are durably stored in GHCR ([ADR-0004](ADR-0004-ghcr.md)), the only genuinely irreplaceable state on the production server is runtime data: databases, object storage, and configuration/secrets. A backup strategy needs to define what is backed up, how often, and where, without over-scoping to data that Git and GHCR already protect.

---

# 2. Decision

Automated, scheduled backup jobs (defined under `infrastructure/backup/`) capture application databases, object storage data, and configuration/secrets on a recurring schedule, encrypt them, and transfer them to storage physically separate from the production server. Application source code and container images are explicitly excluded from backup scope, since they are already durably stored in Git and GHCR respectively.

---

# 3. Alternatives Considered

## 3.1 Full server/disk image backups

Simpler to reason about ("back up everything"), but wasteful and slower to restore: it re-backs-up data (source code, if it were ever present; installed packages) that is either forbidden on production by platform rules or trivially reprovisioned from `docs/04-operations/OPS-001-server-provisioning.md`. Rejected in favor of targeted, faster, cheaper backups scoped to genuinely irreplaceable data.

## 3.2 No automated backup (manual, ad hoc snapshots)

Rejected outright: violates the Automation First and Reproducibility principles ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)) and makes disaster recovery RPO undefined and unreliable.

---

# 4. Consequences

## 4.1 Positive

- Backup jobs run and complete quickly because they only handle data that actually needs protecting.
- Clear, auditable backup scope (Section 3 of [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md)) removes ambiguity about what is and isn't protected.
- Backup storage costs stay proportional to actual data volume, not the entire server's disk.

## 4.2 Negative / Accepted Trade-offs

- If the platform's rule against storing source code or building on production is ever violated in practice (configuration drift), that data would not be backed up. This is mitigated by the rule being structurally enforced (Section 4 of [ADR-0001](ADR-0001-runtime-only.md)) rather than relying on backup as a safety net for a rule violation.

---

# 5. Related Decisions

- [ADR-0002 — Git Source of Truth](ADR-0002-git-source-of-truth.md)
- [ADR-0004 — GHCR](ADR-0004-ghcr.md)

---

# 6. References

- [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md)
- [ARCH-010 — Disaster Recovery Architecture](../01-architecture/ARCH-010-disaster-recovery-architecture.md)
- [OPS-004 — Backup](../04-operations/OPS-004-backup.md)
- [OPS-005 — Restore](../04-operations/OPS-005-restore.md)
