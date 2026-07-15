# .github/

CI workflows for the `platform-production` repository itself, not for any application.

Per [ADR-0001 — Runtime Only](../docs/02-decisions/ADR-0001-runtime-only.md) and [ADR-0003 — GitHub Actions Deployment](../docs/02-decisions/ADR-0003-github-actions-deployment.md), this repository never builds or deploys application code — that happens exclusively in each application repository's own workflow, scaffolded from `templates/`. The workflow here (`workflows/validate.yml`) only:

- validates that every `compose.yaml` under `infrastructure/` and `templates/` is syntactically valid (`docker compose config`);
- checks that relative links between documents in `docs/` resolve;
- lints shell scripts under `infrastructure/` with ShellCheck.

It runs on every pull request and push to `main` and never connects to the production server.
