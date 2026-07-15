# ADR-0011 — Automated Platform Service Deployment Pipeline

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

[ADR-0003 — GitHub Actions Deployment](ADR-0003-github-actions-deployment.md) and [STD-009 — GitHub Actions Standard](../03-standards/STD-009-github-actions-standard.md) establish a fully automated, GitHub-Actions-driven deployment path for **applications**: each application repository builds an image, pushes it to GHCR, and deploys it to `/srv/apps/<app-name>` over SSH.

No equivalent path exists for **platform services** (`infrastructure/traefik`, `infrastructure/monitoring`, `infrastructure/backup`, `infrastructure/networks`). [OPS-001 — Server Provisioning](../04-operations/OPS-001-server-provisioning.md) brings them up once, by hand, during initial provisioning. Every subsequent change — a Traefik version bump, a new dynamic middleware, an adjusted resource limit, a backup schedule change — has had no documented path back to the server at all short of an operator manually re-running `git pull` and `docker compose up -d` on the box, which is exactly the undocumented, unreviewable manual state [ADR-0002 — Git Source of Truth](ADR-0002-git-source-of-truth.md) and the Automation First goal in [ARCH-001 — Platform Vision](../01-architecture/ARCH-001-platform-vision.md) exist to prevent.

The immediate trigger was the Traefik `v3.1` → `v3.7` compatibility fix for Docker Engine 29.x: shipping that fix required exactly the manual SSH path this ADR closes. The gap is structural, not specific to Traefik — it applies equally to `monitoring/` and `backup/`, and to any platform service added in the future.

Platform services differ from applications in one load-bearing way that shapes the design: their images (`traefik`, `henrygd/beszel`, `louislam/uptime-kuma`) are pulled directly from public registries, never built by this repository or pushed to GHCR. There is nothing to build. What changes is configuration — `compose.yaml`, `traefik.yml`, dynamic middleware files, the backup `crontab` — not source code compiled into an image.

---

# 2. Decision

`platform-production` owns a second, independent GitHub Actions pipeline — `.github/workflows/deploy-platform.yml` and the reusable `.github/workflows/deploy-component.yml` it calls — that deploys `infrastructure/<component>` directories to `/srv/platform/<component>` on the production server whenever they change on `main`. This pipeline:

- **never builds anything.** It syncs configuration files with `rsync` and runs `docker compose pull` (pulling the version-pinned public image already referenced in `compose.yaml`) and `docker compose up -d`, per [ADR-0001 — Runtime Only](ADR-0001-runtime-only.md).
- **deploys only components that changed**, determined by diffing the triggering push against its parent commit, so a Traefik-only change never touches `monitoring/` or `backup/`.
- **connects to the same production server, over the same kind of SSH deploy key, as application deployments** (Section 4.1 below), but is a structurally separate workflow from any application's `deploy.yml`, because it deploys a different directory tree (`/srv/platform` vs. `/srv/apps`) governed by a different repository (`platform-production` vs. the application's own repository).
- is a **reusable workflow** (`workflow_call`) parameterized by component name, invoked once per changed component via a matrix job, so adding a fifth platform service later requires no new workflow file — only a new `infrastructure/<component>/` directory.

This does not change how applications deploy. [ADR-0003](ADR-0003-github-actions-deployment.md) and [STD-009](../03-standards/STD-009-github-actions-standard.md) remain the sole path for application deployment, unmodified.

---

# 3. Alternatives Considered

## 3.1 Extend each application's `deploy.yml` pattern to `infrastructure/`

Give `platform-production` a single `deploy.yml` matching STD-009's application shape (build → push → deploy). Rejected: there is nothing to build — platform-service images are pulled from public registries, not built from this repository's source. Forcing a build stage that produces nothing would be dead weight, and STD-009's rules (commit-SHA image tagging, GHCR push) are meaningless for an image this repository never builds.

## 3.2 Continue deploying platform services manually, but document the manual steps more thoroughly

Rejected: this is the status quo the Traefik incompatibility just demonstrated is inadequate. A documented manual procedure is still a manual procedure — it still permits configuration drift between what's in Git and what's running, and still depends on an operator being available and error-free, violating the Automation First and Reproducibility principles in [ARCH-001](../01-architecture/ARCH-001-platform-vision.md).

## 3.3 A pull-based agent on the server that watches this repository for changes

Rejected for the same reason [ADR-0003, Section 3.3](ADR-0003-github-actions-deployment.md#33-pull-based-deployment-agent-on-the-server-eg-a-poller-that-watches-for-new-images) rejected it for applications: it adds an always-running, repository-polling component to the production server that duplicates what a push-triggered CI step already does more simply, with a clearer audit trail.

## 3.4 One combined workflow file deploying every component on every push to `infrastructure/`, with no change detection

Simpler to write, but violates Requirement 5 of the driving task (intelligent, component-scoped deployment) and needlessly recreates every platform-service container — including Traefik, the platform's sole public entrypoint — on every unrelated infrastructure change, e.g., a backup script edit momentarily interrupting live traffic. Rejected in favor of the path-diff-and-matrix approach in Section 2.

---

# 4. Consequences

## 4.1 Positive

- Closes the exact gap the Traefik `v3.1`/Docker Engine 29.x incompatibility exposed: a platform-service configuration or version change now reaches production the same way an application change does — reviewed, automated, and auditable — with no faster manual path that bypasses Git.
- `infrastructure/traefik`, `infrastructure/monitoring`, `infrastructure/backup`, and `infrastructure/networks` each deploy independently; an operator can ship a Traefik change without touching, restarting, or risking `monitoring` or `backup`.
- A future platform service (e.g., a log shipper) is onboarded by adding a directory under `infrastructure/`, not by writing a new workflow file, because the deploy logic is a single reusable workflow.
- The manual path in [OPS-001, Step 9](../04-operations/OPS-001-server-provisioning.md#3-procedure) is reduced to what it can never avoid — creating `/srv/platform/<component>/.env` from a value that is never committed to Git — with the deployment itself handled by the pipeline from the first run onward.

## 4.2 Negative / Accepted Trade-offs

- `platform-production`'s own GitHub Actions now hold a production SSH deploy key, the same trust level already extended to every application repository. This is not new risk introduced by this decision so much as the same, already-accepted risk model in [ARCH-007, Section 4.1](../01-architecture/ARCH-007-security-architecture.md#4-security-boundaries) applied to one more repository.
- A configuration change that recreates Traefik still causes the brief, sub-few-second interruption documented in [ARCH-005, Section 9](../01-architecture/ARCH-005-deployment-strategy.md#9-downtime-expectations) for the same single-replica reason applications have it; this pipeline does not add or remove that trade-off, it just automates reaching it.
- Bootstrapping a brand-new server still requires one manual step before the pipeline can run anything: populating each component's `.env` on the server, since `.env` values are never committed, per [STD-005](../03-standards/STD-005-environment-variables.md).

---

# 5. Related Decisions

- [ADR-0001 — Runtime Only](ADR-0001-runtime-only.md) — this pipeline never builds; it only syncs, pulls, and applies.
- [ADR-0002 — Git Source of Truth](ADR-0002-git-source-of-truth.md) — the principle this decision closes the last gap in.
- [ADR-0003 — GitHub Actions Deployment](ADR-0003-github-actions-deployment.md) — the equivalent, unmodified decision for application deployment.

---

# 6. References

- [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md)
- [STD-011 — Platform Deployment Pipeline Standard](../03-standards/STD-011-platform-deployment-pipeline-standard.md)
- [OPS-011 — Deploy Platform Service](../04-operations/OPS-011-deploy-platform-service.md)
- [OPS-001 — Server Provisioning](../04-operations/OPS-001-server-provisioning.md)
