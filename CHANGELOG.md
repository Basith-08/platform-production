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

## [Unreleased]

Nothing yet. See [ROADMAP v2](docs/05-roadmap/ROADMAP-v2.md) for planned next-scope candidates.
