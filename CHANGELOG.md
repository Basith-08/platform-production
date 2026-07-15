# Changelog

All notable changes to this repository are documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] — 2026-07-15

### Added

- Complete documentation set: 10 architecture documents (`ARCH-001`–`ARCH-010`), 10 architecture decision records (`ADR-0001`–`ADR-0010`), 10 standards (`STD-001`–`STD-010`), 10 operational runbooks (`OPS-001`–`OPS-010`), and roadmap documentation (v1, v2, future expansion, technical debt, future features).
- Documentation templates for architecture documents, ADRs, standards, operations, and application `README.md` files (`docs/00-templates/`).
- Platform service infrastructure: Traefik (reverse proxy/TLS), Beszel (resource monitoring), Uptime Kuma (availability monitoring), scheduled encrypted backup jobs, and shared Docker network definitions (`infrastructure/`).
- Application onboarding templates: backend, frontend, telegram-bot, and worker, each with a `Dockerfile`, `compose.yaml`, GitHub Actions deploy workflow, and `README.md` (`templates/`).
- Root project files: `README.md`, `LICENSE` (MIT), `VERSION`, and this `CHANGELOG.md`.

### Established

- Docker Compose–only production runtime with no Kubernetes, Docker Swarm, or Portainer ([ADR-0001](docs/02-decisions/ADR-0001-runtime-only.md)).
- Git as the sole source of truth for all infrastructure and application configuration ([ADR-0002](docs/02-decisions/ADR-0002-git-source-of-truth.md)).
- GitHub Actions as the sole CI/CD and deployment mechanism ([ADR-0003](docs/02-decisions/ADR-0003-github-actions-deployment.md)).
- GitHub Container Registry as the sole image registry, with every image tagged by Git commit SHA and `latest` never used ([ADR-0004](docs/02-decisions/ADR-0004-ghcr.md), [ADR-0005](docs/02-decisions/ADR-0005-git-commit-sha-tags.md)).
- Traefik as the platform's sole public entrypoint and TLS terminator ([ADR-0006](docs/02-decisions/ADR-0006-traefik.md)).
- Local Docker logging without centralized aggregation, and a lightweight Beszel/Uptime Kuma monitoring stack, as deliberate scale-appropriate trade-offs ([ADR-0008](docs/02-decisions/ADR-0008-logging-strategy.md), [ADR-0009](docs/02-decisions/ADR-0009-monitoring-stack.md)).
- Scheduled, encrypted, offsite backups scoped to irreplaceable data only ([ADR-0010](docs/02-decisions/ADR-0010-backup-strategy.md)).

---

## [1.1.0] — 2026-07-15

### Added

- Automated, component-scoped Platform Deployment Pipeline (`.github/workflows/deploy-platform.yml`, reusable `.github/workflows/deploy-component.yml`) that deploys `infrastructure/traefik`, `infrastructure/monitoring`, `infrastructure/backup`, and `infrastructure/networks` to production on push to `main`, deploying only the components whose files changed, with no build stage and no application code involved ([ADR-0011](docs/02-decisions/ADR-0011-platform-service-deployment-pipeline.md), [STD-011](docs/03-standards/STD-011-platform-deployment-pipeline-standard.md), [OPS-011](docs/04-operations/OPS-011-deploy-platform-service.md)).
- `infrastructure/automation/deploy-component.sh` — applies and health-verifies one platform-service component on the production server.
- `infrastructure/automation/detect-changed-components.sh` — determines which platform-service components changed for a given push or manual dispatch.

### Changed

- `infrastructure/traefik/compose.yaml` pins `image: traefik:v3.7` (previously `v3.1`), resolving a Docker API incompatibility with Docker Engine 29.x.
- `docs/01-architecture/ARCH-002-platform-architecture.md`, `docs/01-architecture/ARCH-005-deployment-strategy.md` (new Section 11 — Platform Service Deployment), and `docs/01-architecture/ARCH-003-directory-structure.md` updated to document the platform-service deployment pipeline alongside the existing application deployment pipeline.
- `docs/02-decisions/ADR-0002-git-source-of-truth.md`, `docs/02-decisions/ADR-0003-github-actions-deployment.md`, and `docs/03-standards/STD-009-github-actions-standard.md` updated with cross-references clarifying their scope is application deployment specifically, distinct from [ADR-0011](docs/02-decisions/ADR-0011-platform-service-deployment-pipeline.md) / [STD-011](docs/03-standards/STD-011-platform-deployment-pipeline-standard.md).
- `docs/04-operations/OPS-001-server-provisioning.md`, Step 9 (renumbered): platform services are now deployed via the pipeline instead of a manual `docker compose up -d`; Step 10 (renumbered) adds `platform-production` itself to the repositories that need `PROD_HOST`/`PROD_DEPLOY_USER`/`PROD_DEPLOY_KEY` secrets.
- `infrastructure/traefik/README.md`, `infrastructure/monitoring/README.md`, `infrastructure/backup/README.md`, `infrastructure/networks/README.md`, and `infrastructure/automation/README.md` updated to describe pipeline-driven deployment instead of a one-time manual step.
- `.github/README.md` corrected: this repository's workflows now do connect to the production server, narrowly, for platform-service deployment.

### Fixed

- `infrastructure/backup/crontab` referenced `run-backup.sh` at `/srv/platform-production/...`, a path that is never populated on production (per [ARCH-002, Section 10](docs/01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping), only `/srv/platform` and `/srv/apps` hold runtime state); corrected to `/srv/platform/backup/run-backup.sh`, and removed an erroneous leading `deploy` user field that is only valid in a system-wide crontab, not a per-user one installed via `crontab <file>`.

---

## [Unreleased]

Nothing yet. See [ROADMAP v2](docs/05-roadmap/ROADMAP-v2.md) for planned next-scope candidates.
