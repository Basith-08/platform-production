# OPS-003 — Rollback

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure reverts an application to its last known-good commit SHA. Because every image is tagged with its commit SHA ([ADR-0005](../02-decisions/ADR-0005-git-commit-sha-tags.md)), rollback never requires a rebuild.

---

# 2. Preconditions

- The previous known-good commit SHA is identified (via `git log` on the application repository or the GitHub Actions run history).
- The image for that SHA still exists in GHCR (GHCR retention has not pruned it).
- SSH access to the production server, or the ability to trigger the application's `workflow_dispatch` rollback input per [STD-009, Rule 1](../03-standards/STD-009-github-actions-standard.md#3-rules).

---

# 3. Procedure

## 3.1 Preferred Path — Re-run Deployment for a Prior SHA

1. In the application repository, trigger the deploy workflow manually (`workflow_dispatch`) with the `sha` input set to the last known-good commit SHA.
2. The workflow's deploy step pulls and runs that exact image — no rebuild occurs, since the image already exists in GHCR.
3. Proceed to Section 4 (Verification).

## 3.2 Manual Path (If GitHub Actions Is Unavailable)

1. SSH to the production server as the deploy user.
2. `cd /srv/apps/<app-name>`.
3. Edit `.env` (or the relevant `compose.yaml` image reference) to set the image tag to the last known-good commit SHA.
4. Run `docker compose pull && docker compose up -d`.
5. Record the manual rollback in the incident log per [OPS-008 — Incident Response](OPS-008-incident-response.md).

---

# 4. Verification

- `docker compose ps` shows the container running the expected (rolled-back) image tag.
- The application's healthcheck reports `healthy`.
- Uptime Kuma shows the monitor as "up."
- The specific regression that triggered the rollback is confirmed resolved (manually exercise the affected functionality, or confirm the alerting condition has cleared).

---

# 5. Rollback / Failure Handling

If rolling back to the previous SHA does not resolve the issue, the problem may not be application-code-related (e.g., a database migration that already ran, a downstream dependency outage, or an infrastructure issue). Escalate to [OPS-008 — Incident Response](OPS-008-incident-response.md) rather than continuing to roll back through further historical commits blindly, since a schema migration from the reverted commit may not itself be reversible by redeploying an older image.

---

# 6. References

- [ADR-0005 — Git Commit SHA](../02-decisions/ADR-0005-git-commit-sha-tags.md)
- [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md)
- [STD-009 — GitHub Actions Standard](../03-standards/STD-009-github-actions-standard.md)
- [OPS-002 — Deploy Application](OPS-002-deploy-application.md)
- [OPS-008 — Incident Response](OPS-008-incident-response.md)
