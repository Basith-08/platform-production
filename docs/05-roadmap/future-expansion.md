# ROADMAP — Future Expansion

**Status:** Living Document

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This document tracks longer-horizon expansion ideas that are not yet concrete enough to be [ROADMAP v2](ROADMAP-v2.md) candidates — they lack a defined trigger condition or clear architectural shape. It exists so ideas are captured without prematurely committing to them, per Documentation First ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)).

---

# 2. Expansion Ideas

## 2.1 Additional Application Templates

Beyond `backend/`, `frontend/`, `telegram-bot/`, and `worker/` ([ARCH-003, Section 6](../01-architecture/ARCH-003-directory-structure.md#6-templates-structure-templates)), future templates could include: scheduled batch jobs (as distinct from long-running workers), static documentation sites, and GraphQL gateway services. Each new template category is added only once a real application needs it — templates are extracted from a working application, not designed speculatively.

## 2.2 Multi-Region Deployment

Running the platform across more than one geographic region for latency or resilience reasons. Explicitly out of scope until multi-server scaling ([ROADMAP v2, Section 2.2](ROADMAP-v2.md#22-multi-server-scaling)) is in place — multi-region is a superset of a problem the platform hasn't yet solved at single-region, multi-server scale.

## 2.3 Self-Service Application Onboarding

A CLI or lightweight internal tool that automates the manual steps in [OPS-002, Section 3.2](../04-operations/OPS-002-deploy-application.md#32-onboarding-a-new-application-first-deployment) (directory creation, network setup, Uptime Kuma registration). Candidate once onboarding frequency makes the manual checklist a measurable bottleneck.

## 2.4 Policy-as-Code Enforcement of Standards

Automated linting of `compose.yaml` and GitHub Actions workflows against [STD-001](../03-standards/STD-001-compose-standard.md), [STD-007](../03-standards/STD-007-network-standard.md), [STD-009](../03-standards/STD-009-github-actions-standard.md), and [STD-010](../03-standards/STD-010-security-standard.md), rather than relying solely on manual review. A natural extension of the `.github/` validation workflows already run against this repository.

---

# 3. Promotion Process

An idea in this document is promoted to [ROADMAP v2](ROADMAP-v2.md) once it has a concrete trigger condition and a rough architectural shape. It is promoted to an ADR once the platform team commits to implementing it.

---

# 4. References

- [ROADMAP v1](ROADMAP-v1.md)
- [ROADMAP v2](ROADMAP-v2.md)
- [ROADMAP — Technical Debt](technical-debt.md)
