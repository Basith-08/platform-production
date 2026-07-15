# OPS-008 — Incident Response

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure defines how an operator responds to a platform or application incident detected via monitoring, user report, or direct observation, implementing the operational boundaries in [ARCH-002, Section 12](../01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries).

---

# 2. Preconditions

- Access to the production server, GitHub Actions, GHCR, Beszel, and Uptime Kuma.
- Familiarity with which team owns which application, per [ARCH-002, Section 12](../01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries).

---

# 3. Procedure

## 3.1 Triage

1. Confirm the scope: is this a single application, multiple applications, or the entire platform (Traefik down)?
2. Check Beszel for resource exhaustion (CPU, memory, disk) on the host or the affected container.
3. Check `docker compose logs --tail 200` for the affected service for error output.
4. Check Uptime Kuma's history to determine when the incident started and whether it correlates with a recent deployment.

## 3.2 Classification

| Scope | Platform Team Owns | Application Owner Owns |
|---|---|---|
| Traefik, monitoring, backup, networks down | Yes | N/A |
| Single application down, infrastructure healthy | Supports diagnosis | Owns resolution |
| Single application down due to recent deploy | Supports diagnosis | Owns resolution (likely rollback) |

This classification follows [ARCH-002, Section 12](../01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries) exactly — the Platform Team does not debug application business logic, and application owners do not modify Traefik or platform-service configuration.

## 3.3 Mitigation

1. If the incident correlates with a recent deployment: execute [OPS-003 — Rollback](OPS-003-rollback.md) immediately.
2. If the incident is resource exhaustion: restart the affected container (`docker compose restart <service>`) as an immediate mitigation, then investigate the root cause (undersized resource limit, memory leak, traffic spike) afterward.
3. If the incident is a platform-service failure (Traefik, monitoring): restart the affected platform service; if it does not recover, escalate to a full diagnostic session with `docker compose logs` and, if needed, `docker compose up -d --force-recreate`.
4. If mitigation requires a manual, out-of-band change (bypassing the normal CI/CD path), it must follow the manual/emergency path in [OPS-002, Section 3.3](OPS-002-deploy-application.md#33-manual--emergency-path) and be reconciled back into Git immediately after, per [ADR-0002 — Git Source of Truth](../02-decisions/ADR-0002-git-source-of-truth.md).

## 3.4 Post-Incident

1. Record the incident: timeline, root cause, mitigation applied, and any manual/emergency actions taken outside the normal deployment path.
2. If a manual change was made directly on the production server, open a pull request to reconcile that change back into the relevant repository so Git remains the source of truth.
3. If the incident revealed a gap in monitoring, resource limits, or documentation, file it under [ROADMAP — Technical Debt](../05-roadmap/technical-debt.md).

---

# 4. Verification

- The affected application or service is confirmed healthy via its own healthcheck and Uptime Kuma.
- The incident record is complete and any manual changes are reconciled into Git.

---

# 5. Rollback / Failure Handling

If mitigation attempts do not resolve the incident within a reasonable window, escalate to a full [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md) assessment — the incident may indicate infrastructure-level corruption rather than an application-level fault.

---

# 6. References

- [ARCH-002 — Platform Architecture, Section 12](../01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries)
- [OPS-003 — Rollback](OPS-003-rollback.md)
- [OPS-007 — Monitoring](OPS-007-monitoring.md)
- [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md)
- [ROADMAP — Technical Debt](../05-roadmap/technical-debt.md)
