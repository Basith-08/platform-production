# infrastructure/monitoring/

Beszel (host/container resource metrics) and Uptime Kuma (HTTP(S) availability monitoring and alerting), per [ARCH-009 — Monitoring Architecture](../../docs/01-architecture/ARCH-009-monitoring-architecture.md) and [ADR-0009 — Monitoring Stack](../../docs/02-decisions/ADR-0009-monitoring-stack.md).

## Deploy

First brought up during [OPS-001 — Server Provisioning](../../docs/04-operations/OPS-001-server-provisioning.md), once `/srv/platform/monitoring/.env` has been populated from `.env.example`. Every change to this directory thereafter is deployed automatically by pushing to `main`: [`.github/workflows/deploy-platform.yml`](../../.github/workflows/deploy-platform.yml) detects the change and syncs, pulls, and applies it via [OPS-011 — Deploy Platform Service](../../docs/04-operations/OPS-011-deploy-platform-service.md).

## Registering Applications

New applications are registered as Uptime Kuma monitors as part of onboarding — see [OPS-002, Section 3.2](../../docs/04-operations/OPS-002-deploy-application.md#32-onboarding-a-new-application-first-deployment) and [OPS-007, Section 3.1](../../docs/04-operations/OPS-007-monitoring.md#31-registering-a-new-application-in-uptime-kuma). Resource metrics require no per-application configuration — the Beszel agent collects every running container automatically via the read-only Docker socket mount.

Both dashboards are reachable only through Traefik and require authentication, per [ARCH-007, Section 4.3](../../docs/01-architecture/ARCH-007-security-architecture.md#4-security-boundaries).
