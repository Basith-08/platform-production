# STD-006 — Logging Standard

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard defines how every container must log, implementing [ADR-0008 — Logging Strategy](../02-decisions/ADR-0008-logging-strategy.md).

---

# 2. Scope

Applies to every service in every `compose.yaml` on the platform.

---

# 3. Rules

1. Every service **must** log to stdout/stderr. No service writes application logs to a file inside the container as its primary log destination.
2. Every service **must** declare the `json-file` logging driver explicitly in `compose.yaml`, with `max-size: "10m"` and `max-file: "3"` as the default rotation policy, per [STD-001, Rule 7](STD-001-compose-standard.md).
3. An application with materially higher log volume **may** override the default rotation values, but the override **must** be justified with a comment in `compose.yaml` referencing the reason.
4. Log lines **should** be structured (JSON) where the application framework supports it, to make timestamp-based manual correlation (per [ARCH-009, Section 7](../01-architecture/ARCH-009-monitoring-architecture.md#7-log-visibility)) easier across containers.
5. Logs **must not** contain secrets (passwords, tokens, full credit card numbers, etc.) at any log level. Frameworks with request/response logging **must** redact known-sensitive fields.
6. Log timestamps **must** be in UTC, consistent across every container, so cross-container correlation by timestamp is meaningful.

---

# 4. Examples

## 4.1 Compliant

```yaml
services:
  api:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

## 4.2 Non-Compliant

- A service writing to `/var/log/app/app.log` inside the container with no rotation, silently growing the container's writable layer until disk pressure causes failures.
- A service logging full request bodies including `Authorization` headers in plaintext.

---

# 5. Rationale

This standard exists because, per [ADR-0008](../02-decisions/ADR-0008-logging-strategy.md), the platform deliberately runs no centralized log aggregation — which makes local rotation limits (Rule 2) load-bearing for disk stability, and UTC/structured logging (Rules 4, 6) load-bearing for an operator's ability to manually correlate logs across containers during an incident.

---

# 6. References

- [ADR-0008 — Logging Strategy](../02-decisions/ADR-0008-logging-strategy.md)
- [ARCH-009 — Monitoring Architecture](../01-architecture/ARCH-009-monitoring-architecture.md)
- [STD-001 — Compose Standard](STD-001-compose-standard.md)
- [STD-010 — Security Standard](STD-010-security-standard.md)
