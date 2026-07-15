# app-name (Worker Template)

**Type:** Worker

**Owner:** \<team or individual\>

**Production Hostname:** N/A (background process; no inbound HTTP traffic)

---

## Overview

This is the platform's background worker template: a queue-consuming process with a Redis-backed queue, with no public HTTP exposure.

---

## Architecture

Runtime shape: a `worker` service and a `queue` (Redis) service, both on a private `app-name-internal` network. No attachment to `edge` — this template has no inbound HTTP traffic. See [ARCH-002 — Platform Architecture](../../docs/01-architecture/ARCH-002-platform-architecture.md) and [ARCH-004 — Network Architecture](../../docs/01-architecture/ARCH-004-network-architecture.md).

This repository contains only application source code, its `Dockerfile`, and its GitHub Actions workflow, per [STD-003 — Repository Standard](../../docs/03-standards/STD-003-repository-standard.md).

---

## Local Development

Run locally with your framework's standard tooling against a local Redis instance.

---

## Deployment

Deploys automatically via GitHub Actions on push to `main`, per [ARCH-005 — Deployment Strategy](../../docs/01-architecture/ARCH-005-deployment-strategy.md) and [STD-009 — GitHub Actions Standard](../../docs/03-standards/STD-009-github-actions-standard.md). Production never builds this application.

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `IMAGE_TAG` | Yes | Commit SHA of the image to run; set automatically by the deploy workflow |
| `QUEUE_URL` | Yes | Connection string for the worker's own Redis queue |
| `WORKER_CONCURRENCY` | Yes | Number of jobs processed concurrently |

Follows [STD-005 — Environment Variables](../../docs/03-standards/STD-005-environment-variables.md). Never commit a populated `.env`.

---

## Owner / Support

State ownership and incident contact here, per [ARCH-002, Section 12](../../docs/01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries).
