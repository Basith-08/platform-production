# ADR-0008 — Local Docker Logging Without Centralized Aggregation

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

Every container produces stdout/stderr logs that need to be retained for debugging without exhausting disk space. Centralized log aggregation stacks (e.g., ELK/EFK, Loki) provide cross-service search and long retention but add several always-on services (ingestion, storage, search index, dashboard) to operate, secure, and back up.

---

# 2. Decision

Every container uses Docker's local `json-file` logging driver with explicit size- and file-count-based rotation configured at the Compose level (`max-size`, `max-file`). No centralized log aggregation stack is deployed. Logs are inspected directly via `docker compose logs` / `docker logs` on the production server.

---

# 3. Alternatives Considered

## 3.1 ELK / EFK stack

Rejected for the platform's current scale: Elasticsearch alone typically requires more memory than several of the platform's application containers combined, and operating it (index lifecycle management, cluster health, security) is a disproportionate burden relative to the platform's team size, violating Operational Simplicity ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)).

## 3.2 Grafana Loki

Lighter-weight than ELK, but still adds a persistent service, a query language to learn, and a storage backend to back up. Rejected for v1 on the same operational-overhead grounds; explicitly listed as a candidate to revisit in [ROADMAP v2](../05-roadmap/ROADMAP-v2.md) if operational scale grows past what local logging can reasonably support.

## 3.3 Shipping logs to a third-party SaaS log service

Rejected: introduces an external dependency and recurring cost, and moves operational log data outside the platform's own infrastructure boundary without a demonstrated need at current scale.

---

# 4. Consequences

## 4.1 Positive

- Zero additional always-on services to operate, secure, patch, or back up for logging.
- Log rotation limits prevent unbounded disk growth on the production server without manual intervention.
- Debugging a single application's issue only requires access to that container's own logs — no query language or aggregation system to learn.

## 4.2 Negative / Accepted Trade-offs

- No cross-service log search or correlation; an operator investigating an issue spanning multiple containers must manually correlate logs by timestamp (see [ARCH-009, Section 7](../01-architecture/ARCH-009-monitoring-architecture.md#7-log-visibility)).
- Log retention is bounded by local disk rotation limits, not a long-term searchable archive; historical logs beyond the rotation window are not recoverable.

---

# 5. Related Decisions

- [ADR-0009 — Monitoring Stack](ADR-0009-monitoring-stack.md)

---

# 6. References

- [ARCH-002 — Platform Architecture, Section 4.7](../01-architecture/ARCH-002-platform-architecture.md#4-platform-components)
- [ARCH-009 — Monitoring Architecture](../01-architecture/ARCH-009-monitoring-architecture.md)
- [STD-006 — Logging Standard](../03-standards/STD-006-logging-standard.md)
