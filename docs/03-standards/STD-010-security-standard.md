# STD-010 — Security Standard

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard converts the boundaries defined in [ARCH-007 — Security Architecture](../01-architecture/ARCH-007-security-architecture.md) into concrete, checkable rules.

---

# 2. Scope

Applies to the production server, every `compose.yaml`, every `Dockerfile`, and every GitHub Actions workflow on the platform.

---

# 3. Rules

## 3.1 Access Control

1. SSH password authentication **must** be disabled on the production server (`PasswordAuthentication no` in `sshd_config`).
2. Root SSH login **must** be disabled (`PermitRootLogin no`).
3. The GitHub Actions deploy key **must** be dedicated to CI/CD use and **must not** be reused as a personal developer key.
4. The host firewall **must** default-deny inbound traffic and explicitly allow only ports 22, 80, and 443.

## 3.2 Secrets

5. No credential **may** be committed to any repository, per [STD-005, Rule 2](STD-005-environment-variables.md).
6. GitHub Actions secrets **must** be scoped at the repository level, not the organization level, unless a credential is genuinely shared across every application (e.g., a shared registry token), per least privilege.
7. Production `.env` files **must** be mode `600`, owned by the deploy user, per [STD-005, Rule 6](STD-005-environment-variables.md#3-rules).

## 3.3 Network Exposure

8. Only Traefik **may** publish host ports 80/443, per [STD-007, Rule 5](STD-007-network-standard.md#3-rules).
9. Platform observability dashboards (Beszel, Uptime Kuma) **must** be protected by authentication and routed only through Traefik, never exposed with a direct published port.

## 3.4 Supply Chain

10. Production **must never** execute `docker build`, `git clone`, or `git pull` for application source code, per [ADR-0001](../02-decisions/ADR-0001-runtime-only.md).
11. Every application image **must** be tagged with a Git commit SHA, never `latest`, per [STD-004, Rule 1](STD-004-docker-image-standard.md#3-rules).
12. Base images **must** be version-pinned, per [STD-004, Rule 3](STD-004-docker-image-standard.md#3-rules).

## 3.5 Container Hardening

13. Application containers **must** run as a non-root user, per [STD-004, Rule 4](STD-004-docker-image-standard.md#3-rules).
14. The Docker socket **must not** be mounted into any application container. It **may** be mounted, read-only, into the platform's metrics collection service only.
15. Every service **must** declare explicit resource limits, per [STD-001, Rule 3](STD-001-compose-standard.md#3-rules), so a compromised or malfunctioning container cannot exhaust host resources.

---

# 4. Examples

## 4.1 Compliant `sshd_config` excerpt

```
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

## 4.2 Non-Compliant

- A `compose.yaml` mounting `/var/run/docker.sock` into an application's `api` service.
- A production `.env` file readable by all users (mode `644`).

---

# 5. Rationale

This standard exists so that every boundary described narratively in [ARCH-007 — Security Architecture](../01-architecture/ARCH-007-security-architecture.md) has a specific, pass/fail rule that a reviewer or automated check can verify, rather than relying on a reviewer's subjective judgment of "secure enough."

---

# 6. References

- [ARCH-007 — Security Architecture](../01-architecture/ARCH-007-security-architecture.md)
- [STD-001 — Compose Standard](STD-001-compose-standard.md)
- [STD-004 — Docker Image Standard](STD-004-docker-image-standard.md)
- [STD-005 — Environment Variables](STD-005-environment-variables.md)
- [STD-007 — Network Standard](STD-007-network-standard.md)
- [OPS-001 — Server Provisioning](../04-operations/OPS-001-server-provisioning.md)
- [OPS-008 — Incident Response](../04-operations/OPS-008-incident-response.md)
