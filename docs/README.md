# Platform Documentation

This is the documentation index for `platform-production` — the single source of truth for the platform's architecture, decisions, standards, and operations. See the [root README](../README.md) for a project-level overview.

Documentation is organized into six categories, per [ARCH-003 — Directory Structure, Section 4](01-architecture/ARCH-003-directory-structure.md#4-documentation-structure-docs). Read them in this order for a first pass through the platform:

1. **[00-templates/](00-templates/)** — canonical templates every document below is derived from.
2. **[01-architecture/](01-architecture/)** — what the platform is and why it is shaped this way.
3. **[02-decisions/](02-decisions/)** — the specific technology and pattern choices behind the architecture.
4. **[03-standards/](03-standards/)** — enforceable, checkable rules derived from the architecture.
5. **[04-operations/](04-operations/)** — step-by-step runbooks for operating the platform.
6. **[05-roadmap/](05-roadmap/)** — what's shipped, what's next, and known gaps.

---

## 00-templates/

| Document | Purpose |
|---|---|
| [document-template.md](00-templates/document-template.md) | Generic document skeleton |
| [architecture-template.md](00-templates/architecture-template.md) | Skeleton for new `ARCH-XXX` documents |
| [adr-template.md](00-templates/adr-template.md) | Skeleton for new `ADR-XXXX` documents |
| [standard-template.md](00-templates/standard-template.md) | Skeleton for new `STD-XXX` documents |
| [operation-template.md](00-templates/operation-template.md) | Skeleton for new `OPS-XXX` documents |
| [readme-template.md](00-templates/readme-template.md) | Skeleton for a new application repository's `README.md` |

---

## 01-architecture/

| ID | Document |
|---|---|
| ARCH-001 | [Platform Vision](01-architecture/ARCH-001-platform-vision.md) |
| ARCH-002 | [Platform Architecture](01-architecture/ARCH-002-platform-architecture.md) |
| ARCH-003 | [Directory Structure](01-architecture/ARCH-003-directory-structure.md) |
| ARCH-004 | [Network Architecture](01-architecture/ARCH-004-network-architecture.md) |
| ARCH-005 | [Deployment Strategy](01-architecture/ARCH-005-deployment-strategy.md) |
| ARCH-006 | [Runtime Architecture](01-architecture/ARCH-006-runtime-architecture.md) |
| ARCH-007 | [Security Architecture](01-architecture/ARCH-007-security-architecture.md) |
| ARCH-008 | [Backup Architecture](01-architecture/ARCH-008-backup-architecture.md) |
| ARCH-009 | [Monitoring Architecture](01-architecture/ARCH-009-monitoring-architecture.md) |
| ARCH-010 | [Disaster Recovery Architecture](01-architecture/ARCH-010-disaster-recovery-architecture.md) |

---

## 02-decisions/

| ID | Document |
|---|---|
| ADR-0001 | [Runtime Only](02-decisions/ADR-0001-runtime-only.md) |
| ADR-0002 | [Git Source of Truth](02-decisions/ADR-0002-git-source-of-truth.md) |
| ADR-0003 | [GitHub Actions Deployment](02-decisions/ADR-0003-github-actions-deployment.md) |
| ADR-0004 | [GHCR](02-decisions/ADR-0004-ghcr.md) |
| ADR-0005 | [Git Commit SHA](02-decisions/ADR-0005-git-commit-sha-tags.md) |
| ADR-0006 | [Traefik](02-decisions/ADR-0006-traefik.md) |
| ADR-0007 | [Docker Runtime](02-decisions/ADR-0007-docker-runtime.md) |
| ADR-0008 | [Logging Strategy](02-decisions/ADR-0008-logging-strategy.md) |
| ADR-0009 | [Monitoring Stack](02-decisions/ADR-0009-monitoring-stack.md) |
| ADR-0010 | [Backup Strategy](02-decisions/ADR-0010-backup-strategy.md) |

---

## 03-standards/

| ID | Document |
|---|---|
| STD-001 | [Compose Standard](03-standards/STD-001-compose-standard.md) |
| STD-002 | [Naming Convention](03-standards/STD-002-naming-convention.md) |
| STD-003 | [Repository Standard](03-standards/STD-003-repository-standard.md) |
| STD-004 | [Docker Image Standard](03-standards/STD-004-docker-image-standard.md) |
| STD-005 | [Environment Variables](03-standards/STD-005-environment-variables.md) |
| STD-006 | [Logging Standard](03-standards/STD-006-logging-standard.md) |
| STD-007 | [Network Standard](03-standards/STD-007-network-standard.md) |
| STD-008 | [Volume Standard](03-standards/STD-008-volume-standard.md) |
| STD-009 | [GitHub Actions Standard](03-standards/STD-009-github-actions-standard.md) |
| STD-010 | [Security Standard](03-standards/STD-010-security-standard.md) |

---

## 04-operations/

| ID | Document |
|---|---|
| OPS-001 | [Server Provisioning](04-operations/OPS-001-server-provisioning.md) |
| OPS-002 | [Deploy Application](04-operations/OPS-002-deploy-application.md) |
| OPS-003 | [Rollback](04-operations/OPS-003-rollback.md) |
| OPS-004 | [Backup](04-operations/OPS-004-backup.md) |
| OPS-005 | [Restore](04-operations/OPS-005-restore.md) |
| OPS-006 | [Docker Upgrade](04-operations/OPS-006-docker-upgrade.md) |
| OPS-007 | [Monitoring](04-operations/OPS-007-monitoring.md) |
| OPS-008 | [Incident Response](04-operations/OPS-008-incident-response.md) |
| OPS-009 | [Disaster Recovery](04-operations/OPS-009-disaster-recovery.md) |
| OPS-010 | [Maintenance](04-operations/OPS-010-maintenance.md) |

---

## 05-roadmap/

| Document | Purpose |
|---|---|
| [ROADMAP-v1.md](05-roadmap/ROADMAP-v1.md) | Current shipped scope |
| [ROADMAP-v2.md](05-roadmap/ROADMAP-v2.md) | Planned next-scope candidates and their triggers |
| [future-expansion.md](05-roadmap/future-expansion.md) | Longer-horizon expansion ideas |
| [technical-debt.md](05-roadmap/technical-debt.md) | Tracked gaps between documentation and implementation |
| [future-features.md](05-roadmap/future-features.md) | Platform-level feature candidates |

---

## Documentation Rules

- Every document is numbered sequentially within its category and never renumbered after approval, per [STD-002, Section 3.8](03-standards/STD-002-naming-convention.md#38-documentation-ids).
- Every standard and operational procedure traces back to an architecture document or ADR — there are no free-floating rules.
- New documents are created from the templates in `00-templates/`, not written ad hoc.
