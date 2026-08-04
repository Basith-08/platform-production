# STD-001 — Compose Standard

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard enforces a consistent, safe structure for every `compose.yaml` file on the platform — platform services and applications alike — so that any operator can read any Compose file and know what to expect.

---

# 2. Scope

Applies to every `compose.yaml` in `infrastructure/` and in every application repository. Does not apply to local-development-only Compose overrides, which are owned by the application repository and out of platform scope.

---

# 3. Rules

1. Every service **must** define `restart: unless-stopped`, per [ARCH-006, Section 5](../01-architecture/ARCH-006-runtime-architecture.md#5-container-lifecycle).
2. Every service **must** define a `healthcheck` with `interval`, `timeout`, `retries`, and `start_period` set explicitly (no relying on image defaults).
3. Every service **must** define `deploy.resources.limits.cpus` and `deploy.resources.limits.memory`, per [ARCH-006, Section 6](../01-architecture/ARCH-006-runtime-architecture.md#6-resource-constraints). Unbounded services are non-compliant.
4. Every service's image reference **must** use a Git commit SHA tag for application images, per [STD-004 — Docker Image Standard](STD-004-docker-image-standard.md), or a pinned version tag for platform-service images. `latest` is never used.
5. Every application service that must be publicly reachable **must** be attached to the `edge` network and carry Traefik routing labels; it **must not** publish a host port directly, per [ARCH-004, Section 4](../01-architecture/ARCH-004-network-architecture.md#4-rules).
6. Every backing service (database, cache, object storage) **must** be attached only to its owning application's private `<app-name>-internal` network, never to `edge`.
7. Every service **must** declare `logging.driver: json-file` with explicit `max-size` and `max-file` options, per [STD-006 — Logging Standard](STD-006-logging-standard.md).
8. Volumes **must** be named, declared in the top-level `volumes:` block, and mapped to `/srv/apps/<app-name>/volumes` or `/srv/platform/<service>` on the host, per [STD-008 — Volume Standard](STD-008-volume-standard.md).
9. Environment variables **must** be sourced via `env_file: .env`, never hardcoded as literal secret values in `compose.yaml`, per [STD-005 — Environment Variables](STD-005-environment-variables.md).
10. Service, network, and volume names **must** follow [STD-002 — Naming Convention](STD-002-naming-convention.md).

---

# 4. Examples

## 4.1 Compliant

```yaml
services:
  api:
    image: ghcr.io/org/app-backend:4f2a9c1
    restart: unless-stopped
    env_file: .env
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - edge
      - app-backend-internal
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app-backend.rule=Host(`api.example.com`)"
      - "traefik.http.routers.app-backend.tls.certresolver=letsencrypt"

networks:
  edge:
    external: true
  app-backend-internal:
    driver: bridge
```

## 4.2 Non-Compliant

```yaml
services:
  api:
    image: ghcr.io/org/app-backend:latest   # violates Rule 4
    ports:
      - "3000:3000"                          # violates Rule 5
    environment:
      - DB_PASSWORD=hunter2                  # violates Rule 9
```

---

# 5. Rationale

Every rule in this standard traces directly to a rule established in [ARCH-004](../01-architecture/ARCH-004-network-architecture.md), [ARCH-005](../01-architecture/ARCH-005-deployment-strategy.md), or [ARCH-006](../01-architecture/ARCH-006-runtime-architecture.md). This standard exists so those architectural rules are checkable in a code review rather than left to interpretation.

---

# 6. References

- [ARCH-004 — Network Architecture](../01-architecture/ARCH-004-network-architecture.md)
- [ARCH-006 — Runtime Architecture](../01-architecture/ARCH-006-runtime-architecture.md)
- [STD-002 — Naming Convention](STD-002-naming-convention.md)
- [STD-004 — Docker Image Standard](STD-004-docker-image-standard.md)
- [STD-005 — Environment Variables](STD-005-environment-variables.md)
- [STD-006 — Logging Standard](STD-006-logging-standard.md)
- [STD-008 — Volume Standard](STD-008-volume-standard.md)
