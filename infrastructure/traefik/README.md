# infrastructure/traefik/

Traefik is the platform's sole reverse proxy and TLS termination point. It is the only service permitted to publish host ports 80/443, per [ARCH-004 — Network Architecture](../../docs/01-architecture/ARCH-004-network-architecture.md) and [ADR-0006 — Traefik](../../docs/02-decisions/ADR-0006-traefik.md).

## Layout

- `compose.yaml` — the deployable service definition.
- `traefik.yml` — static configuration (entrypoints, providers, ACME).
- `dynamic/` — dynamic configuration (shared middlewares); watched live, no restart required to apply changes.
- `.env.example` — required environment variables (copy to `.env` on the server, never commit the populated file, per [STD-005](../../docs/03-standards/STD-005-environment-variables.md)).

## Deploy

First brought up during [OPS-001 — Server Provisioning](../../docs/04-operations/OPS-001-server-provisioning.md), once `/srv/platform/traefik/.env` has been populated from `.env.example`. Every change to this directory thereafter — including the Traefik version pin in `compose.yaml` — is deployed automatically by pushing to `main`: [`.github/workflows/deploy-platform.yml`](../../.github/workflows/deploy-platform.yml) detects the change and syncs, pulls, and applies it via [OPS-011 — Deploy Platform Service](../../docs/04-operations/OPS-011-deploy-platform-service.md). Manual `docker compose pull && docker compose up -d` on the server is the documented emergency-only fallback (Section 3.3 of that document), not the routine path.

Applications never modify this directory. An application makes itself routable by adding Traefik labels to its own `compose.yaml` and attaching to the `edge` network — see [STD-001, Rule 5](../../docs/03-standards/STD-001-compose-standard.md#3-rules).

## Dashboard Authentication

The Traefik dashboard router uses the `dashboard-auth` middleware defined in `dynamic/middlewares.yml`, which requires `dynamic/dashboard-users.htpasswd` — generated once during provisioning and never committed to this repository (it is server-side credential material, per [STD-005 — Environment Variables](../../docs/03-standards/STD-005-environment-variables.md)):

```
htpasswd -nb <admin-user> <admin-password> > /srv/platform/traefik/dynamic/dashboard-users.htpasswd
```

Beszel and Uptime Kuma are not protected by this file — they carry their own built-in authentication, per [ARCH-007, Section 4.3](../../docs/01-architecture/ARCH-007-security-architecture.md#4-security-boundaries).
