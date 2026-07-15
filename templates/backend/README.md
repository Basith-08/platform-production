# app-name (Backend Template)

**Type:** Backend

**Owner:** \<team or individual\>

**Production Hostname:** app-name.domain

---

## Overview

This is the platform's backend application template: a containerized API service with a PostgreSQL backing database, scaffolded to conform to every platform standard out of the box. Copy this directory into a new repository and replace every `app-name` and `org` placeholder with the application's actual values.

---

## Architecture

Runtime shape: one `api` service (Node.js, replace with the actual framework/language) and one `db` service (PostgreSQL), on a private `app-name-internal` network, with `api` additionally attached to `edge` and routed by Traefik. See [ARCH-002 — Platform Architecture](../../docs/01-architecture/ARCH-002-platform-architecture.md) for how this fits into the broader platform, and [ARCH-004 — Network Architecture](../../docs/01-architecture/ARCH-004-network-architecture.md) for the network model this `compose.yaml` implements.

This repository contains only application source code, its `Dockerfile`, and its GitHub Actions workflow, per [STD-003 — Repository Standard](../../docs/03-standards/STD-003-repository-standard.md).

---

## Local Development

Run the application locally using your framework's standard tooling (e.g., `npm run dev`) against a local PostgreSQL instance. Local development tooling is owned by this repository, not the platform.

---

## Deployment

Deploys automatically via GitHub Actions on push to `main`, following build → tag (commit SHA) → push (GHCR) → deploy, per [ARCH-005 — Deployment Strategy](../../docs/01-architecture/ARCH-005-deployment-strategy.md) and [STD-009 — GitHub Actions Standard](../../docs/03-standards/STD-009-github-actions-standard.md). Production never builds this application.

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `IMAGE_TAG` | Yes | Commit SHA of the image to run; set automatically by the deploy workflow |
| `PLATFORM_DOMAIN` | Yes | Base domain used to construct the Traefik routing rule |
| `POSTGRES_USER` | Yes | Database user |
| `POSTGRES_PASSWORD` | Yes | Database password |
| `POSTGRES_DB` | Yes | Database name |

Follows [STD-005 — Environment Variables](../../docs/03-standards/STD-005-environment-variables.md). Never commit a populated `.env`.

---

## Owner / Support

State ownership and incident contact here, per [ARCH-002, Section 12](../../docs/01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries).
