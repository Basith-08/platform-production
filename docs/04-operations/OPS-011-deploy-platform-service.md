# OPS-011 — Deploy Platform Service

**Status:** Approved

**Version:** 1.1

**Owner:** Platform Team

**Last Updated:** 2026-08-20

---

# 1. Purpose

Deploy a reviewed change under `infrastructure/<component>/` to
`/srv/platform/<component>` through GitHub Actions. The server receives
configuration only; it never clones this repository, builds images, or stores
application source code.

# 2. Preconditions

- `platform-doctor.sh host` is ready and the deploy key works.
- `PROD_HOST`, `PROD_DEPLOY_USER`, `PROD_DEPLOY_KEY`, and verified
  `PROD_KNOWN_HOSTS` are configured as protected GitHub secrets.
- Runtime files remain provisioned out of band. For Compose components, a
  missing runtime file fails with a path, `.env.example`, and OPS-013 reference.
- `/srv/platform/<component>` exists. `prepare.sh` creates component-specific
  persistent bind directories without deleting data.

# 3. Procedure

## 3.1 Standard path

1. Change the component in a pull request. `validate.yml` checks Compose,
   ShellCheck, links, and automation tests.
2. Merge to `main`. Change detection selects only affected components.
3. If `networks` is selected, the workflow deploys it first and waits for
   success. The remaining selected components then run in a fail-fast=false
   matrix. If `networks` was not selected, no network job is added.
4. The workflow validates the component on the runner, loads the pinned host
   key from `PROD_KNOWN_HOSTS`, and syncs tracked files to
   `/srv/platform/.staging/<component>`. Runtime exclusions (`*.env`, certs,
   `*-data`, staging, backup key, rclone config, generated credentials) are
   protected.
5. Over SSH, `deploy-component.sh` checks required runtime files, validates the
   staged Compose configuration, runs `prepare.sh` if present, and promotes
   tracked files into the live component without deleting excluded runtime
   state.
6. Compose components run `docker compose config`, `pull`, `up -d`, and a
   bounded health check. Backup/maintenance install marked per-user cron
   entries; networks run the idempotent network helper.

## 3.2 Manual trigger

Run `Deploy Platform` with `component` set to one component for a single
deployment. Leave it blank for a full resync. A full resync still orders
`networks` before Traefik/monitoring; unrelated components remain independent
after that prerequisite. During initial provisioning, when backup's
out-of-band runtime files are not ready yet, a manual run may enable
`skip_backup`; this option is intentionally unavailable to push deployments
and must be disabled after `/srv/platform/backup/backup.env`, `backup.key`,
and the rclone config are provisioned.

## 3.3 First deployment and runtime files

1. Create/populate `/srv/platform/traefik/.env` and
   `/srv/platform/monitoring/.env` from their examples.
2. Provision backup runtime files and rclone OAuth/config as described in
   [OPS-004](OPS-004-backup.md) and [OPS-013](OPS-013-manual-configuration-inventory.md).
3. Run the workflow. Do not manually create `edge` or `platform-internal` in
   the normal path; the `networks` component owns them.
4. Run `/srv/platform/automation/platform-doctor.sh full` after deployment.

## 3.4 Emergency path

If Actions is unavailable, SSH as `deploy`, use only the already synchronized
files, and apply the component with the same validation/health expectations.
Do not `git clone`, `git pull`, or build on the server. Record the change and
reconcile it into Git immediately. An emergency manual platform deployment may
use `docker compose config`, `pull`, and `up -d` from the component directory,
but must preserve `.env`, certificates, data directories, backup credentials,
and generated credentials.

# 4. Verification

- Workflow summary reports the network prerequisite and component matrix.
- Compose components report every active service `healthy`, or `running` when
  no healthcheck exists, within the bounded retry window.
- `platform-doctor.sh full` shows host checks and platform state. Optional
  monitoring profiles may correctly report WARN when disabled.
- `crontab -l` contains marked backup/maintenance entries.
- Runtime secrets and persistent directories are unchanged by redeployment.

# 5. Rollback / failure handling

Staging and pre-apply validation prevent a known-invalid Compose manifest from
being promoted. This is not a filesystem transaction: a failure during
promotion or `up -d` can leave the new tracked configuration applied and a
component partially restarted. The workflow surfaces `docker compose ps` and
recent logs. Restore the previous tracked commit through GitHub Actions or the
documented emergency path; do not restore runtime secrets from Git.

# 6. References

- [ADR-0011 — Automated Platform Service Deployment Pipeline](../02-decisions/ADR-0011-platform-service-deployment-pipeline.md)
- [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md)
- [STD-011 — Platform Deployment Pipeline Standard](../03-standards/STD-011-platform-deployment-pipeline-standard.md)
- [OPS-001 — Server Provisioning](OPS-001-server-provisioning.md)
- [OPS-013 — Manual Configuration Inventory](OPS-013-manual-configuration-inventory.md)
