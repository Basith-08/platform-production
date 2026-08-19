# infrastructure/automation/

Scripts invoked by documented operational procedures or by this repository's own GitHub Actions workflows — not run ad hoc without a corresponding OPS reference.

## Scripts

- `bootstrap.sh` — implements [OPS-001 — Server Provisioning](../../docs/04-operations/OPS-001-server-provisioning.md) as explicit `provision` and `harden` phases. Provisioning creates separate `admin`/`deploy` identities, validates the host, installs Docker/Compose and pinned rclone, configures UFW and runtime directories, and leaves SSH hardening pending until access is verified.
- `install-rclone.sh` — installs the pinned official rclone `1.75.0` amd64 release with bounded retries, official SHA256SUMS validation, temporary extraction, atomic replacement, and idempotent version checks.
- `platform-doctor.sh` — read-only `host`, `platform`, or `full` readiness report with PASS/WARN/FAIL/SKIP output and a machine-usable non-zero exit code for failures.
- `health-sweep.sh` — a quick-look diagnostic across every platform service and application, used during [OPS-010 — Maintenance](../../docs/04-operations/OPS-010-maintenance.md) and as a first step in [OPS-008 — Incident Response](../../docs/04-operations/OPS-008-incident-response.md).
- `deploy-component.sh` — runs **on the production server**, invoked over SSH by [`.github/workflows/deploy-component.yml`](../../.github/workflows/deploy-component.yml) after that workflow has staged `infrastructure/<component>/` under `/srv/platform/.staging/`. It validates runtime files, prepares persistent directories, validates Compose, promotes tracked configuration without deleting excluded state, applies the component, and verifies health. See [OPS-011 — Deploy Platform Service](../../docs/04-operations/OPS-011-deploy-platform-service.md).
- `detect-changed-components.sh` — runs **on the GitHub Actions runner**, as the planning step of [`.github/workflows/deploy-platform.yml`](../../.github/workflows/deploy-platform.yml). Diffs the triggering push (or reads a `workflow_dispatch` input) to decide which `infrastructure/<component>/` directories changed, so only affected components are deployed.

Deployment automation for **applications** lives in each application repository's own GitHub Actions workflow (per [STD-009 — GitHub Actions Standard](../../docs/03-standards/STD-009-github-actions-standard.md)), never here. This directory holds provisioning, maintenance, and **platform-service** deployment helpers only — see [STD-011 — Platform Deployment Pipeline Standard](../../docs/03-standards/STD-011-platform-deployment-pipeline-standard.md) for the boundary between the two.
