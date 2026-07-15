# STD-007 — Network Standard

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard makes the network topology defined in [ARCH-004 — Network Architecture](../01-architecture/ARCH-004-network-architecture.md) checkable at the `compose.yaml` level.

---

# 2. Scope

Applies to every `networks:` declaration and every service's network attachment in every `compose.yaml` on the platform.

---

# 3. Rules

1. The `edge` network **must** be declared as `external: true` in every application's `compose.yaml` — applications never create `edge`, only attach to it; it is created once during provisioning ([OPS-001](../04-operations/OPS-001-server-provisioning.md)).
2. Every application **must** define exactly one private network named `<app-name>-internal` (per [STD-002, Section 3.4](STD-002-naming-convention.md#34-docker-network-names)), created by that application's own `compose.yaml`.
3. Only the application's own edge-facing service (e.g., `api`, `web`) **may** attach to both `edge` and `<app-name>-internal`. Backing services (`db`, `cache`, `storage`) **must** attach only to `<app-name>-internal`.
4. No `compose.yaml` **may** declare a network name shared with another application, and no service **may** attach to another application's `<app-name>-internal` network.
5. No service other than Traefik **may** publish a host port via `ports:` in production `compose.yaml`, per [ARCH-004, Rule 1](../01-architecture/ARCH-004-network-architecture.md#4-rules). Any documented exception must include an inline comment citing the justification.
6. Platform services requiring inter-service reachability (Beszel, Uptime Kuma) **must** use the shared `platform-internal` network, not `edge` and not any application's internal network.

---

# 4. Examples

## 4.1 Compliant

```yaml
services:
  api:
    networks: [edge, invoice-api-internal]
  db:
    networks: [invoice-api-internal]

networks:
  edge:
    external: true
  invoice-api-internal:
    driver: bridge
```

## 4.2 Non-Compliant

```yaml
services:
  db:
    networks: [edge]        # violates Rule 3 — backing service on edge
    ports: ["5432:5432"]    # violates Rule 5 — direct host port publish
```

---

# 5. Rationale

This standard is the literal, reviewable enforcement of the isolation guarantees table in [ARCH-004, Section 6](../01-architecture/ARCH-004-network-architecture.md#6-isolation-guarantees). A `compose.yaml` that follows every rule here cannot violate that table.

---

# 6. References

- [ARCH-004 — Network Architecture](../01-architecture/ARCH-004-network-architecture.md)
- [STD-001 — Compose Standard](STD-001-compose-standard.md)
- [STD-002 — Naming Convention](STD-002-naming-convention.md)
