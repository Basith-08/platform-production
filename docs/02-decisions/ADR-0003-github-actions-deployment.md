# ADR-0003 — GitHub Actions as the Sole Deployment Mechanism

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

Given Git as the source of truth ([ADR-0002](ADR-0002-git-source-of-truth.md)), the platform needs one automated mechanism to move a merged commit into a running container in production. Every application repository already lives on GitHub, so the CI/CD system is a natural extension of the same platform, rather than a separate third-party service.

---

# 2. Decision

GitHub Actions is the only system authorized to build application images and trigger production deployments. Each application repository owns a workflow, defined per [STD-009 — GitHub Actions Standard](../03-standards/STD-009-github-actions-standard.md), that builds the Docker image, pushes it to GHCR, and connects to the production server over SSH to run `docker compose pull` and `docker compose up -d`. No other CI/CD system (Jenkins, GitLab CI, CircleCI, manually-run scripts from a developer laptop) is used for production deployment.

This decision covers **application** deployment specifically. Platform-service deployment (Traefik, monitoring, backup — `infrastructure/` in this repository) is likewise GitHub-Actions-only, but is a separate pipeline with no build stage, since those images are never built by this repository; see [ADR-0011 — Automated Platform Service Deployment Pipeline](ADR-0011-platform-service-deployment-pipeline.md).

---

# 3. Alternatives Considered

## 3.1 Third-party CI/CD platform (e.g., Jenkins, CircleCI)

Rejected: adds an additional system to operate, secure, and keep credentials for, with no benefit over GitHub Actions given that source code already lives on GitHub. Splits the deployment audit trail across two systems instead of one.

## 3.2 Manual deployment from a developer machine

Rejected: violates the Automation First principle ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)), is not reproducible, and depends on an individual's local credentials and environment rather than a centrally-managed, auditable pipeline.

## 3.3 Pull-based deployment agent on the server (e.g., a poller that watches for new images)

Rejected: adds an always-running, internet-facing (or registry-polling) component to the production server whose only job duplicates what a push-based CI step already does more simply and with a clearer audit trail (the workflow run itself).

---

# 4. Consequences

## 4.1 Positive

- One deployment mechanism, one place to look for deployment history and logs (the GitHub Actions run).
- Deployment credentials (the SSH deploy key) are centrally managed as GitHub encrypted secrets, not scattered across developer machines.
- Deployment is naturally coupled to the same event (push to the deploy branch) across every application, giving uniform behavior platform-wide, per [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md).

## 4.2 Negative / Accepted Trade-offs

- The platform's deployment capability depends on GitHub Actions' availability. If GitHub Actions is down, new deployments are blocked, though already-running containers are unaffected (see [ARCH-010, Section 4](../01-architecture/ARCH-010-disaster-recovery-architecture.md#4-disaster-scenarios)).

---

# 5. Related Decisions

- [ADR-0002 — Git Source of Truth](ADR-0002-git-source-of-truth.md)
- [ADR-0004 — GHCR](ADR-0004-ghcr.md)
- [ADR-0005 — Git Commit SHA](ADR-0005-git-commit-sha-tags.md)
- [ADR-0011 — Automated Platform Service Deployment Pipeline](ADR-0011-platform-service-deployment-pipeline.md) — the platform-service counterpart to this decision.

---

# 6. References

- [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md)
- [STD-009 — GitHub Actions Standard](../03-standards/STD-009-github-actions-standard.md)
- [OPS-002 — Deploy Application](../04-operations/OPS-002-deploy-application.md)
