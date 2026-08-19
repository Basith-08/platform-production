# STD-009 — GitHub Actions Standard

**Status:** Approved

**Version:** 1.1

**Owner:** Platform Team

**Last Updated:** 2026-08-20

---

# 1. Purpose

This standard defines the required structure and behavior of every application's deployment workflow, implementing [ADR-0003 — GitHub Actions Deployment](../02-decisions/ADR-0003-github-actions-deployment.md) and [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md).

---

# 2. Scope

Applies to every `.github/workflows/deploy.yml` in every application repository. Does not apply to `platform-production`'s own `deploy-platform.yml` / `deploy-component.yml`, which deploy platform-service configuration rather than application images and are governed instead by [STD-011 — Platform Deployment Pipeline Standard](STD-011-platform-deployment-pipeline-standard.md).

---

# 3. Rules

1. The workflow **must** trigger only on `push` to the repository's designated deploy branch (default `main`), plus an optional `workflow_dispatch` trigger for manual redeployment of a specific ref, per [OPS-003 — Rollback](../04-operations/OPS-003-rollback.md).
2. The workflow **must** run the application's automated test suite before the build step; a failing test suite **must** block the build and deploy steps.
3. The workflow **must** build the Docker image using `docker build`/`docker buildx`, tag it with `${{ github.sha }}` (full commit SHA), and push it to GHCR under the application's namespace, per [ADR-0005](../02-decisions/ADR-0005-git-commit-sha-tags.md). It **must not** additionally tag or push `latest`.
4. The workflow **must** authenticate to GHCR using `GITHUB_TOKEN` or a scoped PAT stored as an encrypted secret — never a hardcoded credential.
5. The deploy step **must** connect to the production server over SSH using a dedicated deploy key stored as an encrypted secret, per [ARCH-007, Section 4.1](../01-architecture/ARCH-007-security-architecture.md#4-security-boundaries).
6. The deploy step **must** synchronize the committed `compose.yaml` manifest to `/srv/apps/<app-name>/compose.yaml` without synchronizing source code, `.env`, secrets, or volumes; then it must run `docker compose config`, `docker compose pull`, and `docker compose up -d` in that directory. It **must not** run `docker build`, `git clone`, or any other build command on the production server, per [ADR-0001 — Runtime Only](../02-decisions/ADR-0001-runtime-only.md).
7. Concurrency **must** be scoped by branch/ref (`concurrency: group: deploy-<app-name>, cancel-in-progress: false`) so overlapping deployments of the same application serialize rather than race, per [ARCH-005, Section 7](../01-architecture/ARCH-005-deployment-strategy.md#7-deployment-concurrency).
8. No secret value **may** be echoed, printed, or written to a log step at any point in the workflow.
9. The deploy step **must** use verified `PROD_KNOWN_HOSTS` with strict host-key checking and must fail if that secret is absent.
10. After `up -d`, the workflow **must** perform a bounded health check that accepts `healthy` or `running` only when no healthcheck exists, and must print bounded diagnostics on failure.

---

# 4. Examples

## 4.1 Compliant workflow skeleton

```yaml
name: Deploy
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      sha:
        required: false

concurrency:
  group: deploy-invoice-api
  cancel-in-progress: false

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm test

  build-and-deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - run: |
          docker build -t ghcr.io/org/invoice-api:${{ github.sha }} .
          docker push ghcr.io/org/invoice-api:${{ github.sha }}
      - uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.PROD_DEPLOY_KEY }}
      - run: |
          test -n "${PROD_KNOWN_HOSTS}"
          printf '%s\n' "${PROD_KNOWN_HOSTS}" > ~/.ssh/known_hosts
          rsync -az --checksum -e "ssh -o StrictHostKeyChecking=yes" compose.yaml \
            "${{ secrets.PROD_DEPLOY_USER }}@${{ secrets.PROD_HOST }}:/srv/apps/invoice-api/.compose.yaml.tmp"
          ssh -o StrictHostKeyChecking=yes "${{ secrets.PROD_DEPLOY_USER }}@${{ secrets.PROD_HOST }}" \
            "mv /srv/apps/invoice-api/.compose.yaml.tmp /srv/apps/invoice-api/compose.yaml"
          ssh -o StrictHostKeyChecking=yes "${{ secrets.PROD_DEPLOY_USER }}@${{ secrets.PROD_HOST }}" \
            "cd /srv/apps/invoice-api && sed -i 's|^IMAGE_TAG=.*|IMAGE_TAG=${{ github.sha }}|' .env && docker compose config -q && docker compose pull && docker compose up -d"
        env:
          PROD_KNOWN_HOSTS: ${{ secrets.PROD_KNOWN_HOSTS }}
```

## 4.2 Non-Compliant

- A workflow that runs `docker build` over SSH on the production server.
- A workflow that pushes and deploys the `latest` tag.
- A workflow triggered on every branch push without restriction.

---

# 5. Rationale

Every rule here exists to make the deployment sequence in [ARCH-005, Section 5](../01-architecture/ARCH-005-deployment-strategy.md#5-deployment-sequence) the only possible path from commit to production — there is no compliant workflow shape that builds on production or deploys an untested or unpinned image.

---

# 6. References

- [ADR-0003 — GitHub Actions Deployment](../02-decisions/ADR-0003-github-actions-deployment.md)
- [ADR-0005 — Git Commit SHA](../02-decisions/ADR-0005-git-commit-sha-tags.md)
- [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md)
- [STD-004 — Docker Image Standard](STD-004-docker-image-standard.md)
- [OPS-002 — Deploy Application](../04-operations/OPS-002-deploy-application.md)
