# OPS-011 — Deploy Platform Service

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure covers deploying a change to a platform-service component (`infrastructure/traefik`, `infrastructure/monitoring`, `infrastructure/backup`, `infrastructure/networks`, or a future component under `infrastructure/`), implementing [ADR-0011 — Automated Platform Service Deployment Pipeline](../02-decisions/ADR-0011-platform-service-deployment-pipeline.md). It is the platform-service counterpart to [OPS-002 — Deploy Application](OPS-002-deploy-application.md).

---

# 2. Preconditions

- `/srv/platform/<component>/` already exists on the production server, created by [OPS-001 — Server Provisioning](OPS-001-server-provisioning.md), Step 6 (`bootstrap.sh`).
- For a component that reads a `.env` (`traefik`, `monitoring`): `/srv/platform/<component>/.env` is already populated from that component's `.env.example` and set to mode `600`, per [STD-005 — Environment Variables](../03-standards/STD-005-environment-variables.md). The pipeline never creates or populates `.env` — it is excluded from every sync (Rule 7, [STD-011](../03-standards/STD-011-platform-deployment-pipeline-standard.md)).
- The `PROD_HOST`, `PROD_DEPLOY_USER`, and `PROD_DEPLOY_KEY` secrets are set on the `platform-production` repository (not only on application repositories), per [OPS-001, Step 11](OPS-001-server-provisioning.md#3-procedure).
- `.github/workflows/deploy-platform.yml` and `.github/workflows/deploy-component.yml` exist on `main`, conforming to [STD-011](../03-standards/STD-011-platform-deployment-pipeline-standard.md).

---

# 3. Procedure

## 3.1 Standard Path (Automated)

1. Change the relevant file(s) under `infrastructure/<component>/` (e.g., a version bump in `compose.yaml`, a new file under `traefik/dynamic/`, an updated `crontab` schedule) and open a pull request.
2. `validate.yml` runs on the pull request and confirms the changed `compose.yaml` (if any) is syntactically valid and every documentation link still resolves.
3. Merge the pull request into `main`.
4. `deploy-platform.yml` triggers automatically, determines that `infrastructure/<component>/` changed, and calls `deploy-component.yml` for that component only. Unrelated components are not touched.
5. The deploy job validates the component again, syncs `infrastructure/<component>/` (and `infrastructure/automation/`) to `/srv/platform/<component>/` over `rsync`, then runs `infrastructure/automation/deploy-component.sh <component>` over SSH, which applies the component and polls for health.
6. No manual action is required. Proceed to Section 4 (Verification).

## 3.2 Manual Trigger (Redeploy Without a New Change)

Used to force a resync of a component — for example, after a manual emergency change (Section 3.3) needs reconciling, or to confirm the server matches `main` after an incident:

1. In the `platform-production` repository, run the `Deploy Platform` workflow manually (`workflow_dispatch`).
2. Set the `component` input to the target component name (e.g., `traefik`) to redeploy only that component, or leave it blank to resync every component.
3. Proceed to Section 4 (Verification).

## 3.3 Onboarding a New Platform-Service Component (First Deployment)

1. Create `infrastructure/<component>/` in `platform-production`, following [STD-001 — Compose Standard](../03-standards/STD-001-compose-standard.md) if it is Compose-based.
2. On the production server, create `/srv/platform/<component>/` (extend `bootstrap.sh`'s directory list for future re-provisioning, and create it directly for the current server).
3. If the component reads a `.env`, populate `/srv/platform/<component>/.env` from its `.env.example` and set mode `600`.
4. Merge the new `infrastructure/<component>/` directory into `main`. No workflow change is needed — [STD-011, Rule 4](../03-standards/STD-011-platform-deployment-pipeline-standard.md#3-rules) requires the deploy logic to be component-agnostic, and `detect-changed-components.sh` discovers the new directory automatically.
5. Verify per Section 4.

## 3.4 Manual / Emergency Path

Used only when GitHub Actions is unavailable, mirroring [OPS-002, Section 3.3](OPS-002-deploy-application.md#33-manual--emergency-path). This path still never builds or clones on production:

1. SSH to the production server as the deploy user.
2. `cd /srv/platform/<component>`.
3. Apply the change directly (edit the relevant file, matching what is committed on `main`) and run `docker compose pull && docker compose up -d`, or the component-appropriate action (`crontab crontab` for `backup`; `./create-networks.sh` for `networks`).
4. Record the manual deployment (who, when, why, what changed) in the incident log per [OPS-008 — Incident Response](OPS-008-incident-response.md).
5. Once GitHub Actions is available again, open a pull request making the same change in Git and merge it, so the next automated run reconciles the server with `main` exactly, per [ADR-0002 — Git Source of Truth](../02-decisions/ADR-0002-git-source-of-truth.md).

---

# 4. Verification

- The `Deploy Platform` workflow run shows a green checkmark, and its summary (`$GITHUB_STEP_SUMMARY`) lists the deployed component(s) and a successful result.
- For a Compose-based component: `docker compose ps` in `/srv/platform/<component>` on the server shows every container `healthy` (or `running`, for a service with no healthcheck).
- For `traefik`: `https://<platform-domain>` and `https://traefik.<platform-domain>` respond with a valid TLS certificate.
- For `monitoring`: the Beszel and Uptime Kuma dashboards are reachable through Traefik.
- For `backup`: `crontab -l` on the server (as the deploy user) shows the expected schedule.
- Uptime Kuma shows every affected platform-service monitor as "up" within one polling interval.

---

# 5. Rollback / Failure Handling

If the deploy job's health check fails, the workflow run fails with a non-zero exit status and the job log includes the failing component's `docker compose ps` and recent logs — the component is left in whatever state `docker compose up -d` produced (per [ARCH-005, Section 9](../01-architecture/ARCH-005-deployment-strategy.md#9-downtime-expectations), Compose does not automatically revert a failed recreation). To roll back:

1. Revert the offending commit in `platform-production` (`git revert`) and push to `main`, or manually trigger the workflow (Section 3.2) against the previous known-good commit's ref.
2. If the platform service is customer-facing and currently degraded (most likely `traefik`), do not wait for a full pull-request cycle — use the manual path (Section 3.4) to restore service immediately, then reconcile via Section 3.4, Step 5.
3. Record the incident per [OPS-008 — Incident Response](OPS-008-incident-response.md).

---

# 6. References

- [ADR-0011 — Automated Platform Service Deployment Pipeline](../02-decisions/ADR-0011-platform-service-deployment-pipeline.md)
- [STD-011 — Platform Deployment Pipeline Standard](../03-standards/STD-011-platform-deployment-pipeline-standard.md)
- [OPS-002 — Deploy Application](OPS-002-deploy-application.md)
- [OPS-001 — Server Provisioning](OPS-001-server-provisioning.md)
- [OPS-008 — Incident Response](OPS-008-incident-response.md)
