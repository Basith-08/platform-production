# ADR-0002 — Git Is the Single Source of Truth

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

Infrastructure and application state can be defined in many places: configuration management databases, cloud console UIs, in-place server edits, GUI deployment tools, or Git repositories. The platform needs exactly one authoritative definition of what should be running, so that the production server's actual state can always be reconciled against a known-good, reviewable definition — including after a total server loss (see [ARCH-010 — Disaster Recovery Architecture](../01-architecture/ARCH-010-disaster-recovery-architecture.md)).

---

# 2. Decision

Every piece of infrastructure configuration — platform service definitions, application `compose.yaml` fragments, Traefik configuration, network definitions, backup schedules, and CI/CD workflows — originates from a Git repository (`platform-production` or an application repository). The production server is a deployment target that receives configuration; it is never the place where configuration is authored or the only place it exists.

---

# 3. Alternatives Considered

## 3.1 In-place manual server configuration

Directly editing files or running ad hoc commands on the production server. Rejected: creates undocumented, unreviewable, unreproducible state — the opposite of the Documentation First and Reproducibility principles in [ARCH-001](../01-architecture/ARCH-001-platform-vision.md).

## 3.2 GUI-managed configuration (e.g., Portainer stacks)

Rejected for the same reason it was rejected in [ADR-0001](ADR-0001-runtime-only.md): a UI-driven configuration path is a second source of truth that can silently diverge from Git.

---

# 4. Consequences

## 4.1 Positive

- Every infrastructure change is reviewable via pull request before it reaches production.
- Full history of every configuration change is preserved in Git, supporting audit and incident post-mortems.
- Disaster recovery is reduced to "clone the repositories and redeploy," rather than "reconstruct undocumented server state" (see [ARCH-010](../01-architecture/ARCH-010-disaster-recovery-architecture.md)).

## 4.2 Negative / Accepted Trade-offs

- Any change, however small, requires a Git commit and (for production-affecting changes) a deployment — there is no fast-path manual override in the standard workflow. Emergency exceptions are documented explicitly in [OPS-008 — Incident Response](../04-operations/OPS-008-incident-response.md) and must be reconciled back into Git immediately after use.

---

# 5. Related Decisions

- [ADR-0003 — GitHub Actions Deployment](ADR-0003-github-actions-deployment.md) — the mechanism by which Git state reaches production.

---

# 6. References

- [ARCH-001 — Platform Vision](../01-architecture/ARCH-001-platform-vision.md)
- [ARCH-002 — Platform Architecture, Section 6](../01-architecture/ARCH-002-platform-architecture.md#6-repository-strategy)
