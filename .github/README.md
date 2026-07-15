# .github/

CI/CD workflows for the `platform-production` repository itself — validation of this repository's own content, and deployment of **platform-service infrastructure** (`infrastructure/`). Never application code.

Per [ADR-0001 — Runtime Only](../docs/02-decisions/ADR-0001-runtime-only.md) and [ADR-0003 — GitHub Actions Deployment](../docs/02-decisions/ADR-0003-github-actions-deployment.md), this repository never builds or deploys application code — that happens exclusively in each application repository's own workflow, scaffolded from `templates/`. This repository owns two, deliberately separate, kinds of workflow:

## Validation (`workflows/validate.yml`)

Runs on every pull request and push to `main`, and never connects to the production server:

- validates that every `compose.yaml` under `infrastructure/` and `templates/` is syntactically valid (`docker compose config`);
- checks that relative links between documents in `docs/` resolve;
- lints shell scripts under `infrastructure/` with ShellCheck.

## Platform Deployment (`workflows/deploy-platform.yml`, `workflows/deploy-component.yml`)

Runs on push to `main` when `infrastructure/**` changes (plus manual `workflow_dispatch`), and **does** connect to the production server — this is the one exception to "never connects to production," and it is scoped narrowly: it validates, then syncs configuration and runs `docker compose pull` / `docker compose up -d` for only the `infrastructure/<component>` directories that changed, exactly as [STD-009 — GitHub Actions Standard](../docs/03-standards/STD-009-github-actions-standard.md) already permits for application repositories, but for platform services instead of applications. It never runs `docker build` or `git clone` on the server, per [ADR-0001](../docs/02-decisions/ADR-0001-runtime-only.md). Full rationale: [ADR-0011](../docs/02-decisions/ADR-0011-platform-service-deployment-pipeline.md). Rules: [STD-011](../docs/03-standards/STD-011-platform-deployment-pipeline-standard.md). Operating procedure: [OPS-011](../docs/04-operations/OPS-011-deploy-platform-service.md).
