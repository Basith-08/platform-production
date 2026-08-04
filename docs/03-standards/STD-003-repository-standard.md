# STD-003 — Repository Standard

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard enforces the repository-level separation between infrastructure and application code established in [ARCH-002, Section 6](../01-architecture/ARCH-002-platform-architecture.md#6-repository-strategy) and [ARCH-003, Section 7](../01-architecture/ARCH-003-directory-structure.md#7-application-repository-structure).

---

# 2. Scope

Applies to `platform-production` and to every application repository.

---

# 3. Rules

1. Every application has exactly one repository. No application's code is split across multiple repositories, and no repository contains more than one application's source code.
2. An application repository **must** contain: one `Dockerfile`, one `compose.yaml` fragment, one `.github/workflows/deploy.yml`, one `README.md` (derived from [readme-template.md](../00-templates/readme-template.md)).
3. An application repository **must not** contain: Traefik configuration, monitoring configuration, backup configuration, another application's code, or a populated `.env` file.
4. `platform-production` **must not** contain any application's business logic or source code.
5. Every repository **must** include a `.gitignore` that excludes `.env`, local build artifacts, and editor/OS metadata files.
6. Every repository's default branch is the deploy branch referenced by [ARCH-005, Section 4](../01-architecture/ARCH-005-deployment-strategy.md#4-branching-and-trigger-model), unless a different deploy branch is explicitly documented in that repository's `README.md`.
7. Repository names follow [STD-002 — Naming Convention](STD-002-naming-convention.md).
8. Every application repository is scaffolded from one of the templates in `templates/` ([ARCH-003, Section 6](../01-architecture/ARCH-003-directory-structure.md#6-templates-structure-templates)); ad hoc repository structures are non-compliant.

---

# 4. Examples

## 4.1 Compliant application repository layout

```
invoice-api/
├── src/
├── Dockerfile
├── compose.yaml
├── .github/workflows/deploy.yml
├── .env.example
├── .gitignore
└── README.md
```

## 4.2 Non-Compliant

- An application repository containing a `traefik/` directory (infrastructure leaking into application scope).
- Two unrelated applications sharing one repository with two `Dockerfile`s.
- A committed `.env` file with real credentials.

---

# 5. Rationale

This standard is the checkable expression of the hard boundary defined in [ARCH-001](../01-architecture/ARCH-001-platform-vision.md) and [ARCH-002, Section 6](../01-architecture/ARCH-002-platform-architecture.md#6-repository-strategy): infrastructure never contains application code, and applications never contain infrastructure.

---

# 6. References

- [ARCH-002 — Platform Architecture, Section 6](../01-architecture/ARCH-002-platform-architecture.md#6-repository-strategy)
- [ARCH-003 — Directory Structure, Section 7](../01-architecture/ARCH-003-directory-structure.md#7-application-repository-structure)
- [STD-002 — Naming Convention](STD-002-naming-convention.md)
- [STD-005 — Environment Variables](STD-005-environment-variables.md)
