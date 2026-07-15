# app-name (Frontend Template)

**Type:** Frontend

**Owner:** \<team or individual\>

**Production Hostname:** app-name.domain

---

## Overview

This is the platform's frontend application template: a containerized, server-rendered frontend (e.g., Next.js standalone output) with no backing database, scaffolded to conform to every platform standard out of the box.

---

## Architecture

Runtime shape: a single `web` service on a private `app-name-internal` network, attached to `edge` and routed by Traefik. See [ARCH-002 — Platform Architecture](../../docs/01-architecture/ARCH-002-platform-architecture.md) and [ARCH-004 — Network Architecture](../../docs/01-architecture/ARCH-004-network-architecture.md).

This repository contains only application source code, its `Dockerfile`, and its GitHub Actions workflow, per [STD-003 — Repository Standard](../../docs/03-standards/STD-003-repository-standard.md).

---

## Local Development

Run locally with your framework's standard tooling (e.g., `npm run dev`).

---

## Deployment

Deploys automatically via GitHub Actions on push to `main`, per [ARCH-005 — Deployment Strategy](../../docs/01-architecture/ARCH-005-deployment-strategy.md) and [STD-009 — GitHub Actions Standard](../../docs/03-standards/STD-009-github-actions-standard.md). Production never builds this application.

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `IMAGE_TAG` | Yes | Commit SHA of the image to run; set automatically by the deploy workflow |
| `PLATFORM_DOMAIN` | Yes | Base domain used to construct the Traefik routing rule |
| `NEXT_PUBLIC_API_URL` | Yes | Public URL of the backend API this frontend consumes |

Follows [STD-005 — Environment Variables](../../docs/03-standards/STD-005-environment-variables.md). Never commit a populated `.env`.

---

## Owner / Support

State ownership and incident contact here, per [ARCH-002, Section 12](../../docs/01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries).
