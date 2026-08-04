# STD-004 — Docker Image Standard

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard defines how application images must be built and tagged so that every image in GHCR is traceable, minimal, and safe to run in production, implementing [ADR-0004 — GHCR](../02-decisions/ADR-0004-ghcr.md) and [ADR-0005 — Git Commit SHA](../02-decisions/ADR-0005-git-commit-sha-tags.md).

---

# 2. Scope

Applies to every `Dockerfile` and image build/push step in every application repository. Platform-service images (Traefik, Beszel, Uptime Kuma) are pulled pre-built from their upstream publishers and are covered by Section 6 only.

---

# 3. Rules

1. Every application image **must** be tagged with the full Git commit SHA of the commit it was built from, and **must not** additionally be pushed or referenced as `latest` in production.
2. Every `Dockerfile` **must** use a multi-stage build where the runtime image excludes build tools, source-controlled test files, and package manager caches.
3. Every `Dockerfile`'s base image **must** be pinned to a specific version tag (e.g., `node:20.11-slim`), never a floating major tag (e.g., `node:20`) or `latest`.
4. The final runtime stage **must** run as a non-root user, per [ARCH-007, Section 6](../01-architecture/ARCH-007-security-architecture.md#6-container-level-security), unless the base image provides no non-root option, in which case this exception must be documented in the application's `README.md`.
5. The final image **must not** contain secrets, `.env` files, or SSH keys baked in at build time.
6. The image **must** expose a working `HEALTHCHECK` (via `Dockerfile` `HEALTHCHECK` or the `compose.yaml` `healthcheck` block per [STD-001, Rule 2](STD-001-compose-standard.md)).
7. Image builds **must** happen exclusively in GitHub Actions; a locally-built image is never pushed to GHCR or pulled by production.

---

# 4. Examples

## 4.1 Compliant

```dockerfile
FROM node:20.11-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20.11-slim AS runtime
WORKDIR /app
RUN useradd --system --uid 1001 appuser
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
USER appuser
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD node healthcheck.js
CMD ["node", "dist/main.js"]
```

## 4.2 Non-Compliant

```dockerfile
FROM node:latest        # violates Rule 3
COPY . .
RUN npm install
CMD ["npm", "start"]    # runs as root (violates Rule 4), no HEALTHCHECK (violates Rule 6)
```

---

# 5. Rationale

These rules exist to keep production images minimal (smaller attack surface, faster pulls), traceable (Rule 1, per [ADR-0005](../02-decisions/ADR-0005-git-commit-sha-tags.md)), and safe to run without elevated privileges (Rule 4, per [ARCH-007 — Security Architecture](../01-architecture/ARCH-007-security-architecture.md)).

---

# 6. Platform-Service Images

Traefik, Beszel, and Uptime Kuma images are pulled from their official upstream registries and pinned to a specific version tag in `infrastructure/*/compose.yaml`. They are upgraded deliberately via a reviewed pull request that changes the pinned tag, never via a floating tag, per [OPS-006 — Docker Upgrade](../04-operations/OPS-006-docker-upgrade.md).

---

# 7. References

- [ADR-0004 — GHCR](../02-decisions/ADR-0004-ghcr.md)
- [ADR-0005 — Git Commit SHA](../02-decisions/ADR-0005-git-commit-sha-tags.md)
- [ARCH-007 — Security Architecture](../01-architecture/ARCH-007-security-architecture.md)
- [STD-001 — Compose Standard](STD-001-compose-standard.md)
- [STD-009 — GitHub Actions Standard](STD-009-github-actions-standard.md)
