# ROADMAP — Future Features

**Status:** Living Document

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This document tracks platform-level *feature* ideas — capabilities that extend what the platform offers application owners — as distinct from [ROADMAP — Future Expansion](future-expansion.md), which tracks infrastructural/architectural scaling ideas, and [ROADMAP — Technical Debt](technical-debt.md), which tracks gaps against current commitments.

---

# 2. Candidate Features

## 2.1 Preview Environments per Pull Request

Ephemeral, short-lived deployments for a pull request, torn down automatically on merge or close. Would require a defined subdomain and TLS strategy compatible with Traefik's dynamic routing, and a resource/cost cap so preview environments cannot accumulate indefinitely. Depends on multi-server scaling or careful resource budgeting on the existing single host ([ROADMAP v2, Section 2.2](ROADMAP-v2.md#22-multi-server-scaling)).

## 2.2 Application-Level Dashboards

A lightweight internal status page aggregating each application's Uptime Kuma and Beszel data into one owner-facing view, without requiring direct dashboard access to platform-wide monitoring tools.

## 2.3 Scheduled Job / Cron Primitive

A first-class template (alongside `worker/`) for scheduled batch jobs, distinct from long-running workers, with its own standard for schedule definition and failure alerting.

## 2.4 Automated Dependency and Base Image Update Notifications

Notifying application owners when a newer, security-patched base image version is available, without automatically applying it (which would violate the deliberate-upgrade principle in [STD-004, Section 6](../03-standards/STD-004-docker-image-standard.md#6-platform-service-images)).

---

# 3. Promotion Process

A feature idea here is promoted to an ADR once a specific application need makes it concrete, following the same Documentation First discipline as [ROADMAP — Future Expansion](future-expansion.md).

---

# 4. References

- [ROADMAP v1](ROADMAP-v1.md)
- [ROADMAP v2](ROADMAP-v2.md)
- [ROADMAP — Future Expansion](future-expansion.md)
