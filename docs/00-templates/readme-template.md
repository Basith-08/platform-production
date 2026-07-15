# \<application-name\>

**Type:** Backend | Frontend | Worker | Telegram Bot

**Owner:** \<team or individual\>

**Production Hostname:** \<app\>.\<domain\>

---

## Overview

One paragraph describing what this application does and who uses it.

---

## Architecture

State the runtime shape (framework, language, backing services such as PostgreSQL/Redis/MinIO) and link to the platform's [ARCH-002 — Platform Architecture](https://github.com/<org>/platform-production/blob/main/docs/01-architecture/ARCH-002-platform-architecture.md) for how this application fits into the broader platform.

This repository contains **only** application source code, its `Dockerfile`, and its GitHub Actions workflow. It never contains Traefik configuration, other applications' code, or production secrets, per [STD-003 — Repository Standard](https://github.com/<org>/platform-production/blob/main/docs/03-standards/STD-003-repository-standard.md).

---

## Local Development

Describe how to run the application locally (commands, required environment variables, local dependencies).

---

## Deployment

This application deploys automatically via GitHub Actions on push to the deploy branch, following the platform's standard build → tag (commit SHA) → push (GHCR) → deploy contract defined in [ARCH-005 — Deployment Strategy](https://github.com/<org>/platform-production/blob/main/docs/01-architecture/ARCH-005-deployment-strategy.md). Manual deployment steps, if ever required, are documented in [OPS-002 — Deploy Application](https://github.com/<org>/platform-production/blob/main/docs/04-operations/OPS-002-deploy-application.md).

Production never builds this application. Production only pulls the image GitHub Actions pushed to GHCR.

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `EXAMPLE_VAR` | Yes | Description |

Environment variables follow [STD-005 — Environment Variables](https://github.com/<org>/platform-production/blob/main/docs/03-standards/STD-005-environment-variables.md). Never commit a populated `.env` file to this repository.

---

## Owner / Support

State who owns this application and how to reach them for incidents, per the ownership boundaries in [ARCH-002, Section 12](https://github.com/<org>/platform-production/blob/main/docs/01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries).

> This template lives in `platform-production` at `docs/00-templates/readme-template.md`. Because the resulting `README.md` is copied into a separate application repository, its links to platform documentation use absolute GitHub URLs rather than relative paths — replace `<org>` with the actual GitHub organization/user before use.
