# STD-008 — Volume Standard

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard defines how persistent data is declared, located, and protected, implementing [ARCH-002, Section 10 — Directory Mapping](../01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping) and supporting [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md).

---

# 2. Scope

Applies to every named Docker volume and bind mount declared in any `compose.yaml` on the platform.

---

# 3. Rules

1. Every stateful service **must** use a named Docker volume, never an anonymous volume, per [STD-002, Section 3.5](STD-002-naming-convention.md#35-docker-volume-names).
2. Application volumes **must** map to `/srv/apps/<app-name>/volumes/<volume-name>` on the host. Platform-service volumes **must** map to `/srv/platform/<service>/`. No volume maps outside these two roots.
3. A volume **must not** be shared between two different applications. Cross-application data sharing, if ever required, goes through a defined API, never a shared volume.
4. Every volume containing data classified as "Backed Up: Yes" in [ARCH-008, Section 3](../01-architecture/ARCH-008-backup-architecture.md#3-backup-scope) **must** be registered in the corresponding backup job under `infrastructure/backup/` before the application is considered production-ready.
5. Volumes **must not** be deleted as a side effect of `docker compose down`; destructive volume removal is a deliberate, separate, documented action per [OPS-010 — Maintenance](../04-operations/OPS-010-maintenance.md), never a default.
6. Volume names **must** follow `<app-name>-<purpose>`, per [STD-002, Section 3.5](STD-002-naming-convention.md#35-docker-volume-names).

---

# 4. Examples

## 4.1 Compliant

```yaml
services:
  db:
    volumes:
      - invoice-api-db-data:/var/lib/postgresql/data

volumes:
  invoice-api-db-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /srv/apps/invoice-api/volumes/db-data
```

## 4.2 Non-Compliant

- An anonymous volume (`- /var/lib/postgresql/data` with no name) that Docker garbage-collects unpredictably.
- A volume mounted at an arbitrary host path outside `/srv/apps` or `/srv/platform`.

---

# 5. Rationale

Predictable volume location (Rule 2) is what makes [ARCH-002, Section 10](../01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping) mechanically true rather than aspirational, and is a direct precondition for [OPS-004 — Backup](../04-operations/OPS-004-backup.md) and [OPS-005 — Restore](../04-operations/OPS-005-restore.md) to operate against a known, consistent path structure.

---

# 6. References

- [ARCH-002 — Platform Architecture, Section 10](../01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping)
- [ARCH-008 — Backup Architecture](../01-architecture/ARCH-008-backup-architecture.md)
- [STD-002 — Naming Convention](STD-002-naming-convention.md)
- [OPS-004 — Backup](../04-operations/OPS-004-backup.md)
