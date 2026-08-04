# ROADMAP — Technical Debt

**Status:** Living Document

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This document tracks known gaps between what the platform's documentation prescribes and what has been fully implemented and verified at any point in time, plus deliberate simplifications accepted for v1. It is updated whenever [OPS-008 — Incident Response](../04-operations/OPS-008-incident-response.md) or [OPS-010 — Maintenance](../04-operations/OPS-010-maintenance.md) surfaces a gap.

---

# 2. Tracking Table

| ID | Item | Category | Status | Reference |
|---|---|---|---|---|
| TD-001 | No staging environment; all changes validated by each application's own test suite only before production deploy | Accepted v1 limitation | Open | [ROADMAP v2, Section 2.1](ROADMAP-v2.md#21-staging-environment) |
| TD-002 | Single Traefik instance is a single point of failure for the entire platform | Accepted v1 limitation | Open | [ARCH-004, Section 7](../01-architecture/ARCH-004-network-architecture.md#7-failure-modes) |
| TD-003 | No cross-container log search; incident diagnosis correlates logs manually by timestamp | Accepted v1 limitation | Open | [ADR-0008](../02-decisions/ADR-0008-logging-strategy.md) |
| TD-004 | Onboarding a new application is a manual checklist, not automated tooling | Accepted v1 limitation | Open | [ROADMAP — Future Expansion, Section 2.3](future-expansion.md#23-self-service-application-onboarding) |
| TD-005 | `compose.yaml` and GitHub Actions workflow compliance with standards is reviewed manually, not linted automatically | Accepted v1 limitation | Open | [ROADMAP — Future Expansion, Section 2.4](future-expansion.md#24-policy-as-code-enforcement-of-standards) |

---

# 3. Entry Rules

1. Every entry **must** state which category it falls under: **Accepted v1 limitation** (a known, deliberate trade-off documented elsewhere) or **Unplanned gap** (implementation has drifted from documentation and needs reconciliation).
2. An **Unplanned gap** entry is treated with higher priority than an **Accepted v1 limitation** entry, since it represents documentation and reality diverging — a direct violation of Documentation First ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)).
3. An entry is closed only once the gap is resolved (implemented) or formally accepted long-term via an ADR that supersedes the relevant architectural expectation.

---

# 4. References

- [ROADMAP v1](ROADMAP-v1.md)
- [ROADMAP v2](ROADMAP-v2.md)
- [OPS-008 — Incident Response](../04-operations/OPS-008-incident-response.md)
- [OPS-010 — Maintenance](../04-operations/OPS-010-maintenance.md)
