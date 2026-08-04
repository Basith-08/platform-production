# ADR-0005 — Images Are Tagged With Git Commit SHA Only

**Status:** Accepted

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Context

Every image pushed to GHCR ([ADR-0004](ADR-0004-ghcr.md)) needs a tag. A common convention is to tag the most recent build as `latest` and reference that mutable tag from `compose.yaml`. This makes it impossible to know, from the tag alone, exactly which commit is running, and makes rollback ambiguous (there is no "previous latest" once a new one is pushed).

---

# 2. Decision

Every image is tagged with the full Git commit SHA of the commit it was built from, and `compose.yaml` files reference that exact SHA. The `latest` tag is never pushed and never referenced in any production `compose.yaml`.

---

# 3. Alternatives Considered

## 3.1 `latest` tag

Simple and requires no `compose.yaml` update between deployments. Rejected: `latest` is mutable — the tag's meaning changes with every push — which makes the currently-running image untraceable to a specific commit without separately recording it, and makes rollback require rebuilding an old commit rather than simply pointing at an already-built image.

## 3.2 Semantic version tags (e.g., `v1.4.2`)

Communicates intent well for human consumers but requires a separate versioning/release process (deciding when to bump major/minor/patch) that adds ceremony disproportionate to a platform that deploys on every merge to the deploy branch, per [ARCH-005 — Deployment Strategy](../01-architecture/ARCH-005-deployment-strategy.md). Not rejected outright for all uses — application repositories may additionally tag semantic versions for their own release notes — but it is never the tag production deployment relies on.

---

# 4. Consequences

## 4.1 Positive

- The image running in production is always traceable to an exact, reviewable Git commit — critical for incident investigation and audit.
- Rollback becomes trivial: redeploy with the previous known-good commit SHA, no rebuild required (see [OPS-003 — Rollback](../04-operations/OPS-003-rollback.md)).
- Eliminates an entire class of "it works on my machine but not in prod" ambiguity caused by `latest` resolving to different images at different times.

## 4.2 Negative / Accepted Trade-offs

- Every deployment requires updating the `compose.yaml` image reference (automated by the CI workflow, not manual) rather than simply re-pulling `latest`.
- Commit SHAs are not human-friendly identifiers; operators rely on `git log` or the GitHub Actions run history to map a SHA back to a human-readable change description.

---

# 5. Related Decisions

- [ADR-0004 — GHCR](ADR-0004-ghcr.md)
- [ADR-0003 — GitHub Actions Deployment](ADR-0003-github-actions-deployment.md)

---

# 6. References

- [ARCH-005 — Deployment Strategy, Section 6](../01-architecture/ARCH-005-deployment-strategy.md#6-image-tagging-strategy)
- [STD-004 — Docker Image Standard](../03-standards/STD-004-docker-image-standard.md)
- [OPS-003 — Rollback](../04-operations/OPS-003-rollback.md)
