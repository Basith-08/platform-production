# ROADMAP — v1

**Status:** Active

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This document defines the scope of platform version 1.0.0 — the current, shipped baseline described by every ARCH, ADR, STD, and OPS document in this repository.

---

# 2. Scope of v1

v1 delivers a single-server, Docker Compose–based production platform with:

- Ubuntu 24.04 LTS host running Docker Engine, containerd, and the Compose plugin ([ARCH-006](../01-architecture/ARCH-006-runtime-architecture.md)).
- Traefik as the sole public entrypoint and TLS terminator ([ARCH-004](../01-architecture/ARCH-004-network-architecture.md)).
- Fully automated build → tag (commit SHA) → push (GHCR) → deploy (SSH) pipeline via GitHub Actions, per application repository ([ARCH-005](../01-architecture/ARCH-005-deployment-strategy.md)).
- Two-tier network isolation: shared `edge`, private per-application internal networks ([ARCH-004](../01-architecture/ARCH-004-network-architecture.md)).
- Local `json-file` Docker logging with rotation, no centralized aggregation ([ADR-0008](../02-decisions/ADR-0008-logging-strategy.md)).
- Beszel (resource metrics) and Uptime Kuma (availability) as the monitoring stack ([ARCH-009](../01-architecture/ARCH-009-monitoring-architecture.md)).
- Scheduled, encrypted, offsite backups scoped to databases, object storage, and configuration ([ARCH-008](../01-architecture/ARCH-008-backup-architecture.md)).
- Four onboarding templates: backend, frontend, telegram-bot, worker ([ARCH-003, Section 6](../01-architecture/ARCH-003-directory-structure.md#6-templates-structure-templates)).
- Complete documentation set: 10 architecture documents, 10 ADRs, 10 standards, 10 operational runbooks.

---

# 3. Explicit v1 Non-Goals

Reiterated from [ARCH-001 — Platform Vision](../01-architecture/ARCH-001-platform-vision.md):

- No staging environment.
- No multi-server scaling.
- No Kubernetes, Docker Swarm, or Portainer.
- No centralized log aggregation or full observability stack (Prometheus/Grafana).
- No centralized secrets manager beyond per-application `.env` files.

These are not oversights — each is a deliberate, documented trade-off for Operational Simplicity ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)), revisited in [ROADMAP v2](ROADMAP-v2.md) only if justified by real operational need.

---

# 4. v1 Completion Criteria

v1 is considered complete when:

1. Every document listed in this repository's required document set is approved (no `Draft` status remaining outside of documents explicitly still in review).
2. At least one application has been successfully onboarded end-to-end using [OPS-002, Section 3.2](../04-operations/OPS-002-deploy-application.md#32-onboarding-a-new-application-first-deployment).
3. A full disaster recovery drill ([OPS-009](../04-operations/OPS-009-disaster-recovery.md)) has been executed successfully at least once.
4. A backup restore-test ([OPS-005](../04-operations/OPS-005-restore.md)) has been executed successfully at least once.

---

# 5. References

- [ARCH-001 — Platform Vision](../01-architecture/ARCH-001-platform-vision.md)
- [ROADMAP v2](ROADMAP-v2.md)
- [ROADMAP — Future Expansion](future-expansion.md)
