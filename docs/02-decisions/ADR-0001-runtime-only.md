# ADR-0001 — Production Server Is Docker Runtime Only

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

The platform needs a production execution environment for multiple independently-owned applications. Common approaches range from a full container orchestrator (Kubernetes), to a lighter clustering tool (Docker Swarm) with a management UI (Portainer), to plain Docker Compose on a single host. The platform is currently small in scale (a handful of applications, single production server) and is operated by a small team without dedicated platform-engineering headcount.

---

# 2. Decision

The production server runs Docker Engine, containerd, and the Docker Compose plugin only. No Kubernetes, no Docker Swarm, and no Portainer (or any other GUI-based deployment manager) is installed or used to manage production workloads. All workload definitions are expressed as `compose.yaml` files, and all orchestration is `docker compose pull` / `docker compose up -d`.

---

# 3. Alternatives Considered

## 3.1 Kubernetes

Provides multi-node scheduling, self-healing, and a large ecosystem. Rejected: the operational overhead (cluster control plane, CNI, ingress controllers, RBAC, etcd management) is disproportionate to a single-host, small-application-count deployment, and would work directly against the Operational Simplicity principle in [ARCH-001](../01-architecture/ARCH-001-platform-vision.md).

## 3.2 Docker Swarm

Lighter than Kubernetes, native to Docker, provides multi-node scheduling. Rejected: the platform currently has exactly one production host, so multi-node scheduling provides no benefit today, while still adding cluster-state complexity (raft consensus, node management) that a single Compose host does not have.

## 3.3 Portainer (or similar GUI deployment manager)

Provides a web UI over Docker for managing containers, stacks, and networks. Rejected: it introduces a second, UI-driven source of deployment state that can drift from what is declared in Git, directly violating the Git as Source of Truth principle ([ARCH-001](../01-architecture/ARCH-001-platform-vision.md)). Any configuration made through a UI and not captured in a `compose.yaml` committed to a repository is, by definition, undocumented and unreproducible.

---

# 4. Consequences

## 4.1 Positive

- Minimal operational surface: one runtime, one CLI, one declarative file format (`compose.yaml`) per service.
- Every deployable unit is fully described in Git; there is no drift between "what's running" and "what's declared," because there is no alternate mechanism to change what's running.
- New team members only need to learn Docker Compose, not a cluster orchestrator.

## 4.2 Negative / Accepted Trade-offs

- No automatic multi-node failover: a total loss of the single production server takes down every application until [OPS-009 — Disaster Recovery](../04-operations/OPS-009-disaster-recovery.md) is executed. This is an accepted trade-off at current scale (see [ARCH-010 — Disaster Recovery Architecture](../01-architecture/ARCH-010-disaster-recovery-architecture.md) for RTO/RPO targets).
- No built-in rolling/blue-green deployment; deployments incur brief downtime (see [ARCH-005, Section 9](../01-architecture/ARCH-005-deployment-strategy.md#9-downtime-expectations)).
- Scaling beyond a single host requires a future architectural change, which must go through a new ADR before implementation (see [ROADMAP v2](../05-roadmap/ROADMAP-v2.md)).

---

# 5. Related Decisions

- [ADR-0007 — Docker Runtime](ADR-0007-docker-runtime.md) — the specific runtime stack this decision constrains.

---

# 6. References

- [ARCH-001 — Platform Vision](../01-architecture/ARCH-001-platform-vision.md)
- [ARCH-006 — Runtime Architecture](../01-architecture/ARCH-006-runtime-architecture.md)
