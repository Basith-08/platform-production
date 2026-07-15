# app-name (Telegram Bot Template)

**Type:** Telegram Bot

**Owner:** \<team or individual\>

**Production Hostname:** N/A (long-polling; no inbound HTTP traffic)

---

## Overview

This is the platform's Telegram bot template: a long-running, long-polling bot process with a Redis-backed cache, with no public HTTP exposure. If the bot uses a webhook instead of long-polling, see the note in `compose.yaml` for how to attach it to `edge` and add Traefik routing.

---

## Architecture

Runtime shape: a `bot` service and a `cache` (Redis) service, both on a private `app-name-internal` network. Because this template has no inbound HTTP traffic, it is not attached to `edge` by default. See [ARCH-002 — Platform Architecture](../../docs/01-architecture/ARCH-002-platform-architecture.md) and [ARCH-004 — Network Architecture](../../docs/01-architecture/ARCH-004-network-architecture.md).

This repository contains only application source code, its `Dockerfile`, and its GitHub Actions workflow, per [STD-003 — Repository Standard](../../docs/03-standards/STD-003-repository-standard.md).

---

## Local Development

Run locally with your framework's standard tooling. Use a personal test bot token, never the production `TELEGRAM_BOT_TOKEN`.

---

## Deployment

Deploys automatically via GitHub Actions on push to `main`, per [ARCH-005 — Deployment Strategy](../../docs/01-architecture/ARCH-005-deployment-strategy.md) and [STD-009 — GitHub Actions Standard](../../docs/03-standards/STD-009-github-actions-standard.md). Production never builds this application.

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `IMAGE_TAG` | Yes | Commit SHA of the image to run; set automatically by the deploy workflow |
| `TELEGRAM_BOT_TOKEN` | Yes | Bot token issued by BotFather; treat as a secret |
| `REDIS_URL` | Yes | Connection string for the bot's own Redis cache |

Follows [STD-005 — Environment Variables](../../docs/03-standards/STD-005-environment-variables.md). Never commit a populated `.env`.

---

## Owner / Support

State ownership and incident contact here, per [ARCH-002, Section 12](../../docs/01-architecture/ARCH-002-platform-architecture.md#12-operational-boundaries).
