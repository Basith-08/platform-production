# ROADMAP — v2

**Status:** Planned

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This document defines the candidate scope for platform version 2 — capabilities intentionally deferred from v1 because they were not yet justified by operational need, per the Operational Simplicity principle in [ARCH-001](../01-architecture/ARCH-001-platform-vision.md). None of these items begin implementation without a preceding ADR, per [ARCH-002, Section 14](../01-architecture/ARCH-002-platform-architecture.md#14-future-expansion).

---

# 2. Candidate Scope

## 2.1 Staging Environment

A staging environment mirroring production topology, allowing the same immutable, commit-SHA-tagged images to be validated before promotion to production. Trigger for prioritization: an incident traceable to a change that staging would have caught.

## 2.2 Multi-Server Scaling

Separating the data tier (PostgreSQL, Redis, MinIO) from the application tier onto dedicated hosts, connected via shared overlay networks. Trigger: single-host resource ceiling reached (sustained high Beszel utilization across multiple applications, see [OPS-007](../04-operations/OPS-007-monitoring.md)).

## 2.3 Highly Available Traefik

Multiple Traefik instances behind a load balancer or DNS failover, removing the single point of failure noted in [ARCH-004, Section 7](../01-architecture/ARCH-004-network-architecture.md#7-failure-modes). Trigger: an uptime SLA commitment that a single Traefik instance cannot meet.

## 2.4 Centralized Secrets Management

Replacing per-application `.env` files with a dedicated secrets manager (e.g., HashiCorp Vault, or a cloud provider's secrets service), reducing manual `.env` provisioning risk as application count grows. Trigger: application count or `.env` rotation frequency makes manual provisioning ([STD-005](../03-standards/STD-005-environment-variables.md)) error-prone.

## 2.5 Log Aggregation

Introducing centralized log search (e.g., Grafana Loki), superseding the local-only logging in [ADR-0008](../02-decisions/ADR-0008-logging-strategy.md). Trigger: an incident response materially slowed by the inability to search logs across containers ([ARCH-009, Section 7](../01-architecture/ARCH-009-monitoring-architecture.md#7-log-visibility)).

## 2.6 Expanded Observability Stack

Prometheus/Grafana for custom metrics and richer alerting rules, superseding or supplementing Beszel/Uptime Kuma ([ADR-0009](../02-decisions/ADR-0009-monitoring-stack.md)). Trigger: a monitoring need Beszel/Uptime Kuma cannot express (custom application-level metrics, multi-condition alerts).

## 2.7 Zero-Downtime Deployments

Rolling or blue-green deployment support, removing the brief interruption noted in [ARCH-005, Section 9](../01-architecture/ARCH-005-deployment-strategy.md#9-downtime-expectations). Trigger: an application with an uptime requirement that cannot tolerate deployment-time interruption.

---

# 3. Explicit Exclusion

Orchestration beyond Docker Compose (Kubernetes, Docker Swarm) remains out of scope even for v2 planning purposes, per [ADR-0001 — Runtime Only](../02-decisions/ADR-0001-runtime-only.md). It is only reconsidered under the specific condition in [ARCH-002, Section 14](../01-architecture/ARCH-002-platform-architecture.md#14-future-expansion) (approaching roughly 50 independently deployed applications or a genuine multi-node autoscaling requirement) and requires a dedicated ADR superseding ADR-0001, not a v2 roadmap decision alone.

---

# 4. Process

Every item in Section 2, when its trigger condition is met, is proposed as a new ADR in `docs/02-decisions/` before any implementation work begins, per the Documentation First principle ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)). This roadmap records candidates and their triggers; it does not itself authorize implementation.

---

# 5. References

- [ROADMAP v1](ROADMAP-v1.md)
- [ARCH-002 — Platform Architecture, Section 14](../01-architecture/ARCH-002-platform-architecture.md#14-future-expansion)
- [ROADMAP — Future Expansion](future-expansion.md)
