# infrastructure/automation/

Scripts invoked by documented operational procedures — not run ad hoc without a corresponding OPS reference.

## Scripts

- `bootstrap.sh` — implements [OPS-001 — Server Provisioning](../../docs/04-operations/OPS-001-server-provisioning.md), Steps 1–6 (deploy user, SSH hardening, firewall, Docker installation, directory layout).
- `health-sweep.sh` — a quick-look diagnostic across every platform service and application, used during [OPS-010 — Maintenance](../../docs/04-operations/OPS-010-maintenance.md) and as a first step in [OPS-008 — Incident Response](../../docs/04-operations/OPS-008-incident-response.md).

Deployment automation itself lives in each application repository's own GitHub Actions workflow (per [STD-009 — GitHub Actions Standard](../../docs/03-standards/STD-009-github-actions-standard.md)), not here — this directory holds only platform-level provisioning and maintenance helpers.
