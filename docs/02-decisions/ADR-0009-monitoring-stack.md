# ADR-0009 — Beszel and Uptime Kuma as the Monitoring Stack

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

The platform needs visibility into both resource health (CPU, memory, disk, network) and service availability (is an endpoint actually responding). Full observability platforms (Prometheus + Grafana + Alertmanager) provide this and more, at the cost of additional operated services, consistent with the trade-off already made for logging in [ADR-0008](ADR-0008-logging-strategy.md).

---

# 2. Decision

Beszel is used for host and container resource metrics. Uptime Kuma is used for HTTP(S) endpoint availability monitoring and alerting. No additional metrics time-series database or dashboarding stack (e.g., Prometheus/Grafana) is deployed in v1.

---

# 3. Alternatives Considered

## 3.1 Prometheus + Grafana + Alertmanager

Industry-standard, highly flexible, but requires operating a time-series database, a scraping/exporter model per service, a dashboarding service, and a separate alert-routing service. Rejected for v1 on Operational Simplicity grounds ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)); explicitly a candidate for [ROADMAP v2](../05-roadmap/ROADMAP-v2.md) if the number of applications or the need for custom metrics/alerting rules grows beyond what Beszel and Uptime Kuma can express.

## 3.2 Cloud-provider-native monitoring

Rejected: the platform is designed to be portable across hosting providers (see [ARCH-001, Non-Goals](../01-architecture/ARCH-001-platform-vision.md) — no lock-in to a specific PaaS), and provider-native monitoring would tie observability to a specific host provider.

---

# 4. Consequences

## 4.1 Positive

- Both tools are lightweight, quick to deploy as ordinary platform services under `infrastructure/monitoring/`, and require no dedicated metrics storage tuning.
- Uptime Kuma's built-in alerting (email/webhook) covers the platform's primary incident-detection need — "is something down" — without a separate alerting system.
- Beszel's resource view answers the most common first diagnostic question during an incident ("is the host or a container out of CPU/memory/disk") directly.

## 4.2 Negative / Accepted Trade-offs

- No custom metrics or complex alerting rules (e.g., multi-condition alerts, long-term trend analysis) — only what Beszel and Uptime Kuma natively expose.
- No long-term metrics retention/analysis beyond what each tool stores natively.

---

# 5. Related Decisions

- [ADR-0008 — Logging Strategy](ADR-0008-logging-strategy.md)

---

# 6. References

- [ARCH-002 — Platform Architecture, Section 4.5–4.6](../01-architecture/ARCH-002-platform-architecture.md#4-platform-components)
- [ARCH-009 — Monitoring Architecture](../01-architecture/ARCH-009-monitoring-architecture.md)
- [OPS-007 — Monitoring](../04-operations/OPS-007-monitoring.md)
