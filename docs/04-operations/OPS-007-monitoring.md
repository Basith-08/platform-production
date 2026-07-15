# OPS-007 — Monitoring

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure covers configuring monitoring for a new application and the routine checks an operator performs, implementing [ARCH-009 — Monitoring Architecture](../01-architecture/ARCH-009-monitoring-architecture.md).

---

# 2. Preconditions

- Beszel and Uptime Kuma are deployed and reachable, per [OPS-001 — Server Provisioning](OPS-001-server-provisioning.md).
- The application to be monitored exposes a health endpoint consistent with its `compose.yaml` `healthcheck`, per [STD-001, Rule 2](../03-standards/STD-001-compose-standard.md#3-rules).

---

# 3. Procedure

## 3.1 Registering a New Application in Uptime Kuma

1. Log in to the Uptime Kuma dashboard (reachable through Traefik).
2. Add a new monitor: type HTTP(S), URL set to the application's public health endpoint.
3. Set the polling interval (default 60 seconds unless the application justifies a different value).
4. Attach the monitor to the appropriate notification channel (email or chat webhook) for the application's owner, per [ARCH-002, Section 12 — Operational Boundaries](../01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries).
5. Confirm the monitor immediately shows "up."

## 3.2 Routine Resource Check (Beszel)

Performed as part of [OPS-010 — Maintenance](OPS-010-maintenance.md) or ad hoc when investigating performance:

1. Open the Beszel dashboard.
2. Review host-level CPU, memory, disk, and network utilization trends.
3. Review per-container resource usage against the limits declared in each `compose.yaml` ([STD-001, Rule 3](../03-standards/STD-001-compose-standard.md#3-rules)); a container consistently near its limit is a candidate for a limit increase or an application-level investigation.
4. Flag any host disk utilization trending toward capacity — this affects both application operation and backup staging ([ARCH-008, Section 4](../01-architecture/ARCH-008-backup-architecture.md#4-backup-flow)).

## 3.3 Responding to an Alert

1. On receiving an Uptime Kuma "down" notification, confirm the outage is real (not a transient blip) by checking the dashboard directly.
2. Proceed to [OPS-008 — Incident Response](OPS-008-incident-response.md).

---

# 4. Verification

- Every application and platform service has an active Uptime Kuma monitor in the "up" state under normal operation.
- Beszel reports metrics for every running container, with no gaps in the collection timeline.

---

# 5. Rollback / Failure Handling

If Uptime Kuma or Beszel itself becomes unreachable, this is itself an incident — the platform temporarily loses its primary detection mechanism for other failures. Escalate immediately per [OPS-008 — Incident Response](OPS-008-incident-response.md) rather than treating it as routine.

---

# 6. References

- [ARCH-009 — Monitoring Architecture](../01-architecture/ARCH-009-monitoring-architecture.md)
- [ADR-0009 — Monitoring Stack](../02-decisions/ADR-0009-monitoring-stack.md)
- [OPS-008 — Incident Response](OPS-008-incident-response.md)
- [OPS-010 — Maintenance](OPS-010-maintenance.md)
