# ADR-0007 — Docker Engine, containerd, and Compose Plugin as the Runtime Stack

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

[ADR-0001](ADR-0001-runtime-only.md) establishes that the platform runs on Docker Compose without an orchestrator. This ADR records the specific runtime components chosen to implement that decision and the operating system they run on.

---

# 2. Decision

The production server runs Ubuntu 24.04 LTS as the host operating system, with Docker Engine (installed from Docker's official APT repository), containerd as the underlying low-level runtime, and the Docker Compose plugin (`docker compose`, not the legacy standalone `docker-compose` binary) as the sole orchestration interface.

---

# 3. Alternatives Considered

## 3.1 Podman

Rootless-by-default and Docker-CLI-compatible. Rejected for v1: smaller operational familiarity within the team compared to Docker Engine, and some platform services (e.g., certain monitoring agents) have more mature, better-documented support for Docker specifically. Revisitable via a new ADR if rootless-by-default becomes a hard requirement.

## 3.2 Legacy standalone `docker-compose` (Python, v1 binary)

Deprecated upstream in favor of the Compose plugin (`docker compose`, v2, written in Go and integrated into the Docker CLI). Rejected: using a deprecated tool would mean building on a component no longer receiving active development.

## 3.3 Non-LTS or rolling-release Linux distribution

Rejected: production infrastructure prioritizes stability and a long, predictable security-patch window over access to newer packages, consistent with Security First and Operational Simplicity ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)).

---

# 4. Consequences

## 4.1 Positive

- Ubuntu 24.04 LTS provides a five-year security maintenance window, reducing forced upgrade churn.
- Docker Engine + Compose plugin is the most widely documented, broadly supported combination for the platform's chosen deployment model.
- containerd, as Docker Engine's dependency, requires no independent management — it is upgraded transparently alongside Docker Engine.

## 4.2 Negative / Accepted Trade-offs

- Docker Engine (versus Podman) runs a root-owned daemon by default; this is mitigated at the container level per [ARCH-007, Section 6](../01-architecture/ARCH-007-security-architecture.md#6-container-level-security) (non-root container users, no Docker socket mounted into application containers) rather than by switching runtimes.

---

# 5. Related Decisions

- [ADR-0001 — Runtime Only](ADR-0001-runtime-only.md)

---

# 6. References

- [ARCH-006 — Runtime Architecture](../01-architecture/ARCH-006-runtime-architecture.md)
- [OPS-001 — Server Provisioning](../04-operations/OPS-001-server-provisioning.md)
- [OPS-006 — Docker Upgrade](../04-operations/OPS-006-docker-upgrade.md)
