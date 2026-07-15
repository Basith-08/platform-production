# ADR-0006 — Traefik as the Sole Reverse Proxy

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

The platform hosts multiple applications on a single server and needs one component to terminate TLS, route requests by hostname, and be the only process exposed to the internet, per the network isolation goals in [ARCH-004 — Network Architecture](../01-architecture/ARCH-004-network-architecture.md). Candidates include Traefik, Nginx (with manually maintained config or a companion like nginx-proxy), and Caddy.

---

# 2. Decision

Traefik is the platform's sole reverse proxy and TLS termination point. It is the only container permitted to publish host ports 80 and 443, and it discovers routing rules for each application via Docker labels on that application's own `compose.yaml`, avoiding a centrally-maintained routing config file.

---

# 3. Alternatives Considered

## 3.1 Nginx with manually maintained virtual host files

Mature and well understood, but requires editing a central Nginx config (or reloading it) every time an application is onboarded, and requires a separate tool (e.g., certbot) for TLS certificate issuance and renewal. Rejected: couples onboarding a new application to editing shared infrastructure configuration, working against Single Responsibility and Operational Simplicity ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)).

## 3.2 Caddy

Also supports automatic TLS and reasonably simple configuration. Rejected primarily on ecosystem grounds: Traefik's native Docker provider (label-based service discovery) is a more direct fit for a Compose-only, multi-application platform where every application's routing rule should live in that application's own `compose.yaml`, per [ARCH-002, Section 6 — Repository Strategy](../01-architecture/ARCH-002-platform-architecture.md#6-repository-strategy).

---

# 4. Consequences

## 4.1 Positive

- Onboarding a new application requires no change to shared Traefik configuration — only labels in the new application's own `compose.yaml`, keeping infrastructure and application concerns cleanly separated.
- Automatic TLS certificate issuance and renewal via ACME, removing a manual operational task.
- A single, consistent routing and TLS story across every application on the platform.

## 4.2 Negative / Accepted Trade-offs

- Traefik is a single point of failure for platform-wide reachability (see [ARCH-004, Section 7 — Failure Modes](../01-architecture/ARCH-004-network-architecture.md#7-failure-modes)). Multi-instance Traefik is deferred to [ROADMAP v2](../05-roadmap/ROADMAP-v2.md).
- Operators must understand Traefik's label-based configuration syntax, which is a learning curve distinct from a traditional Nginx config file.

---

# 5. Related Decisions

- [ADR-0007 — Docker Runtime](ADR-0007-docker-runtime.md)

---

# 6. References

- [ARCH-002 — Platform Architecture, Section 4.1](../01-architecture/ARCH-002-platform-architecture.md#4-platform-components)
- [ARCH-004 — Network Architecture](../01-architecture/ARCH-004-network-architecture.md)
