# OPS-006 — Docker Upgrade

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure upgrades Docker Engine, containerd, and the Compose plugin on the production server in a controlled, low-risk manner, implementing [ADR-0007 — Docker Runtime](../02-decisions/ADR-0007-docker-runtime.md).

---

# 2. Preconditions

- A recent successful backup exists, per [OPS-004 — Backup](OPS-004-backup.md).
- The target Docker Engine version has been reviewed against the current Compose files for known breaking changes (consult Docker's release notes).
- A maintenance window is scheduled, per [OPS-010 — Maintenance](OPS-010-maintenance.md), since this procedure briefly interrupts all running containers.

---

# 3. Procedure

1. Announce the maintenance window per [OPS-010 — Maintenance](OPS-010-maintenance.md) if any application has known consumers who should be notified.
2. SSH to the production server as the deploy user.
3. Record the current Docker version for rollback reference: `docker version > ~/docker-version-before-upgrade.txt`.
4. Update the package index and inspect available versions: `apt update && apt list --upgradable | grep docker`.
5. Upgrade Docker Engine, CLI, containerd, and the Compose plugin:
   ```
   apt install --only-upgrade docker-ce docker-ce-cli containerd.io docker-compose-plugin
   ```
6. Restart the Docker daemon if not restarted automatically by the package manager: `systemctl restart docker`.
7. Confirm every container comes back up automatically (per `restart: unless-stopped`, [ARCH-006, Section 5](../01-architecture/ARCH-006-runtime-architecture.md#5-container-lifecycle)): `docker ps` should list every expected container as `Up`.
8. If any container did not restart automatically, bring it up explicitly: `cd /srv/apps/<app-name> && docker compose up -d` (repeat for `/srv/platform/*`).

---

# 4. Verification

- `docker version` and `docker compose version` report the expected new versions.
- Every platform service and application container is `Up` and reports `healthy`.
- Uptime Kuma shows every monitor as "up" within one polling interval post-upgrade.
- Beszel shows normal resource utilization (no runaway CPU/memory post-restart).

---

# 5. Rollback / Failure Handling

If the upgrade causes containers to fail to start (e.g., a Compose syntax incompatibility), downgrade Docker Engine to the version recorded in Step 3 using `apt install docker-ce=<version> docker-ce-cli=<version> containerd.io=<version>`, then restart Docker and re-verify. If downgrade does not resolve the issue, escalate to [OPS-008 — Incident Response](OPS-008-incident-response.md).

---

# 6. References

- [ADR-0007 — Docker Runtime](../02-decisions/ADR-0007-docker-runtime.md)
- [ARCH-006 — Runtime Architecture](../01-architecture/ARCH-006-runtime-architecture.md)
- [OPS-004 — Backup](OPS-004-backup.md)
- [OPS-010 — Maintenance](OPS-010-maintenance.md)
