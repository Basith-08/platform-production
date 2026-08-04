# ADR-0004 — GitHub Container Registry as the Sole Image Registry

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

Built images need durable storage between the CI build step and the production `docker compose pull` step. Options include GitHub Container Registry (GHCR), Docker Hub, or a self-hosted registry. Given [ADR-0003](ADR-0003-github-actions-deployment.md) already commits the platform to GitHub Actions, registry choice should minimize additional systems and credentials to manage.

---

# 2. Decision

GitHub Container Registry (GHCR) is the only container image registry used by the platform. Every application image is pushed to GHCR under its owning repository's namespace by GitHub Actions, and the production server only ever pulls from GHCR.

---

# 3. Alternatives Considered

## 3.1 Docker Hub

Widely used, but a separate account/credential set from GitHub, separate rate limits, and separate access control to manage alongside the GitHub-based CI/CD already chosen. Rejected in favor of keeping registry and CI/CD credentials unified under GitHub's own permission model.

## 3.2 Self-hosted registry

Would run on the production server or a dedicated host. Rejected: contradicts [ADR-0001 — Runtime Only](ADR-0001-runtime-only.md) by adding another always-on service to operate and secure, and reintroduces a single point of failure that is also the deployment target itself — if the server hosting the registry is the same server pulling from it, a corrupted registry can take down the same host it's meant to serve.

---

# 4. Consequences

## 4.1 Positive

- GHCR access control reuses the same GitHub organization/repository permissions already governing source code, avoiding a second credential system.
- Image push (from Actions) and image pull (from production) both authenticate via tokens scoped through GitHub, keeping the supply chain within one trust boundary.
- Every image is directly traceable to the repository and commit that produced it via GHCR's package-to-repository linkage.

## 4.2 Negative / Accepted Trade-offs

- The platform's ability to deploy depends on GHCR's availability, same as any external registry choice. Already-running containers are unaffected by a GHCR outage (see [ARCH-010, Section 4](../01-architecture/ARCH-010-disaster-recovery-architecture.md#4-disaster-scenarios)).

---

# 5. Related Decisions

- [ADR-0003 — GitHub Actions Deployment](ADR-0003-github-actions-deployment.md)
- [ADR-0005 — Git Commit SHA](ADR-0005-git-commit-sha-tags.md)

---

# 6. References

- [ARCH-002 — Platform Architecture, Section 4.3](../01-architecture/ARCH-002-platform-architecture.md#4-platform-components)
- [STD-004 — Docker Image Standard](../03-standards/STD-004-docker-image-standard.md)
