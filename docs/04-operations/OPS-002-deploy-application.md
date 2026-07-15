# OPS-002 — Deploy Application

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure covers both the standard automated deployment path and the exceptional manual path for deploying an application, implementing [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md).

---

# 2. Preconditions

- The application repository has a working `.github/workflows/deploy.yml` conforming to [STD-009 — GitHub Actions Standard](../03-standards/STD-009-github-actions-standard.md).
- For a new application: `/srv/apps/<app-name>/` exists on the production server with a populated `.env`, per [OPS-002 onboarding checklist below].
- The application's private network exists or will be created by its `compose.yaml`.

---

# 3. Procedure

## 3.1 Standard Path (Automated)

1. Merge a change into the application repository's deploy branch (default `main`).
2. GitHub Actions triggers automatically: runs tests, builds the image, tags it with the commit SHA, pushes to GHCR.
3. The workflow's deploy step connects to the production server via SSH and runs `docker compose pull && docker compose up -d` inside `/srv/apps/<app-name>`.
4. No manual action is required. Proceed to Section 4 (Verification).

## 3.2 Onboarding a New Application (First Deployment)

1. Create the application repository from the appropriate template under `templates/` ([ARCH-003, Section 6](../01-architecture/ARCH-003-directory-structure.md#6-templates-structure-templates)).
2. On the production server, create `/srv/apps/<app-name>/` and `/srv/apps/<app-name>/volumes/`.
3. Populate `/srv/apps/<app-name>/.env` from the application's `.env.example`, per [STD-005 — Environment Variables](../03-standards/STD-005-environment-variables.md); set mode `600`.
4. Copy the application's `compose.yaml` fragment into `/srv/apps/<app-name>/compose.yaml` (this is committed to the application repository and pulled/copied by the deploy step, not hand-edited on the server thereafter).
5. Add GitHub Actions secrets (`PROD_HOST`, `PROD_DEPLOY_USER`, `PROD_DEPLOY_KEY`) to the application repository.
6. Register the application's health endpoint in Uptime Kuma, per [ARCH-009, Section 5](../01-architecture/ARCH-009-monitoring-architecture.md#5-what-is-monitored).
7. Point DNS for the application's hostname at the production server.
8. Trigger the first deployment by pushing to the deploy branch (Section 3.1).

## 3.3 Manual / Emergency Path

Used only when GitHub Actions is unavailable (see [ARCH-010, Section 4](../01-architecture/ARCH-010-disaster-recovery-architecture.md#4-disaster-scenarios)). This path still never builds on production:

1. Confirm the target image (built by a prior successful CI run) already exists in GHCR at the desired commit SHA.
2. SSH to the production server as the deploy user.
3. `cd /srv/apps/<app-name>`.
4. Update the image tag reference in `.env` or `compose.yaml` to the target commit SHA.
5. Run `docker compose pull && docker compose up -d`.
6. Record the manual deployment (who, when, why, which SHA) in the incident log per [OPS-008 — Incident Response](OPS-008-incident-response.md), since this bypasses the normal CI audit trail.

---

# 4. Verification

- The deployed container reports `healthy` (`docker compose ps`).
- Traefik routes requests to the new container (check response headers or a version endpoint if the application exposes one).
- Uptime Kuma shows the application's monitor as "up" within one polling interval.
- The GitHub Actions workflow run (standard path) shows a green checkmark.

---

# 5. Rollback / Failure Handling

If the deployed container fails its healthcheck or the application misbehaves post-deploy, follow [OPS-003 — Rollback](OPS-003-rollback.md) immediately. Do not attempt to debug in place if the application is customer-facing and currently degraded — roll back first, investigate second.

---

# 6. References

- [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md)
- [STD-009 — GitHub Actions Standard](../03-standards/STD-009-github-actions-standard.md)
- [STD-005 — Environment Variables](../03-standards/STD-005-environment-variables.md)
- [OPS-003 — Rollback](OPS-003-rollback.md)
- [OPS-008 — Incident Response](OPS-008-incident-response.md)
