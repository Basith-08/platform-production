# STD-011 — Platform Deployment Pipeline Standard

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard defines the required structure and behavior of `platform-production`'s own platform-service deployment workflows, implementing [ADR-0011 — Automated Platform Service Deployment Pipeline](../02-decisions/ADR-0011-platform-service-deployment-pipeline.md). It is the platform-service counterpart to [STD-009 — GitHub Actions Standard](STD-009-github-actions-standard.md), which governs application deployment workflows instead.

---

# 2. Scope

Applies to `.github/workflows/deploy-platform.yml`, `.github/workflows/deploy-component.yml`, and `infrastructure/automation/deploy-component.sh` / `detect-changed-components.sh` in the `platform-production` repository. Does not apply to any application repository's `deploy.yml` (STD-009 governs those) or to `infrastructure/automation/bootstrap.sh` (a one-time provisioning script, per [OPS-001](../04-operations/OPS-001-server-provisioning.md), not a deployment workflow).

---

# 3. Rules

1. The pipeline **must** trigger only on `push` to `main` with changes under `infrastructure/**`, plus a `workflow_dispatch` trigger accepting an optional single-component input, per [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md#4-branching-and-trigger-model). It **must not** trigger on a pull request or deploy anything from a branch other than `main`.
2. The pipeline **must never** run `docker build` on behalf of a platform-service component. Every platform-service image is a version-pinned public image already referenced in that component's `compose.yaml`, per [STD-001, Rule 4](STD-001-compose-standard.md#3-rules); the pipeline's only image-related action is `docker compose pull`.
3. The pipeline **must** determine which `infrastructure/<component>` directories changed and deploy only those, per [ARCH-005, Section 7](../01-architecture/ARCH-005-deployment-strategy.md#7-deployment-concurrency) applied at platform-service granularity. It **must not** redeploy every component on a change scoped to one component, except when the change is under the shared `infrastructure/compose/` fragments directory, which is treated as affecting every component.
4. Each component **must** deploy through a single reusable workflow (`workflow_call`), invoked once per changed component, so that adding a new platform-service component never requires a new workflow file — only a new `infrastructure/<component>/` directory.
5. Concurrency **must** be scoped per component (`concurrency: group: deploy-platform-<component>, cancel-in-progress: false`), never by the whole pipeline, so that an in-flight deployment of one component never blocks or is blocked by a deployment of an unrelated component.
6. The deploy step **must** connect to the production server over SSH using the same class of dedicated deploy key used for application deployments (`PROD_HOST`, `PROD_DEPLOY_USER`, `PROD_DEPLOY_KEY`, stored as encrypted repository secrets on `platform-production`), per [ARCH-007, Section 4.1](../01-architecture/ARCH-007-security-architecture.md#4-security-boundaries).
7. Syncing a component's files to the server **must** exclude every path that holds runtime state or secrets not tracked in Git: `.env`, TLS certificate storage, per-service data directories (e.g., `beszel-data/`, `kuma-data/`), backup staging, `backup.key`, and any generated credential file (e.g., `dashboard-users.htpasswd`), per [STD-005 — Environment Variables](STD-005-environment-variables.md) and [ARCH-007, Section 4.2](../01-architecture/ARCH-007-security-architecture.md#4-security-boundaries). A sync **must not** delete an excluded path even when using a mirroring transfer mode.
8. The pipeline **must** verify the deployed component before reporting success: for a Compose-based component, every container **must** report `healthy` (or, absent a healthcheck, `running`) within a bounded retry window; a failed verification **must** fail the workflow with a non-zero exit status and surface the component's logs.
9. The pipeline **must** produce a deployment report summarizing the triggering commit, the components deployed, and the result, visible on the workflow run (e.g., a `$GITHUB_STEP_SUMMARY` entry).
10. No secret value **may** be echoed, printed, or written to a log step at any point in the workflow, per [STD-009, Rule 8](STD-009-github-actions-standard.md#3-rules).

---

# 4. Examples

## 4.1 Compliant: adding a new platform service

Adding `infrastructure/log-shipper/compose.yaml` (a hypothetical future component) requires no new workflow file. The next push touching `infrastructure/log-shipper/` is picked up by the existing change-detection step, deployed through the existing reusable workflow with `component: log-shipper`, and verified the same way every other component is.

## 4.2 Non-Compliant

- A workflow that redeploys `traefik`, `monitoring`, and `backup` together whenever any one of them changes.
- A workflow step that runs `docker build` for a platform-service image.
- A sync step using `rsync --delete` without excluding `certs/`, which would delete the live TLS certificate store on every Traefik deployment.
- A single shared concurrency group covering every component, so a slow `backup` deployment delays an urgent `traefik` fix.

---

# 5. Rationale

Platform services and applications share a runtime (Docker Compose on the same server) but differ in what "deploy" means for each: an application deployment ships new code; a platform-service deployment ships new configuration for an image this repository never builds. This standard exists so that difference is expressed as one small, reusable, component-scoped pipeline rather than either forcing platform services into STD-009's build-and-push shape (Section 3.1 of [ADR-0011](../02-decisions/ADR-0011-platform-service-deployment-pipeline.md)) or leaving them undocumented and manual, which is the gap ADR-0011 closes.

---

# 6. References

- [ADR-0011 — Automated Platform Service Deployment Pipeline](../02-decisions/ADR-0011-platform-service-deployment-pipeline.md)
- [ADR-0001 — Runtime Only](../02-decisions/ADR-0001-runtime-only.md)
- [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md)
- [STD-009 — GitHub Actions Standard](STD-009-github-actions-standard.md)
- [STD-005 — Environment Variables](STD-005-environment-variables.md)
- [OPS-011 — Deploy Platform Service](../04-operations/OPS-011-deploy-platform-service.md)
