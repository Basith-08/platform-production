# STD-005 — Environment Variables Standard

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard defines how configuration and secrets are supplied to containers, implementing the Secrets boundary defined in [ARCH-007, Section 4.2](../01-architecture/ARCH-007-security-architecture.md#4-security-boundaries).

---

# 2. Scope

Applies to every `.env` file and every environment variable consumed by a container on the platform.

---

# 3. Rules

1. Every application's runtime configuration **must** be supplied via a `.env` file at `/srv/apps/<app-name>/.env` on the production server, referenced from `compose.yaml` via `env_file:`, per [STD-001, Rule 9](STD-001-compose-standard.md).
2. A populated `.env` file **must never** be committed to any Git repository. Every repository **must** include `.env` in `.gitignore`.
3. Every application repository **must** provide a `.env.example` file listing every required variable name with a placeholder or empty value, never a real secret.
4. Variable names **must** follow `UPPER_SNAKE_CASE`, per [STD-002, Section 3.6](STD-002-naming-convention.md#36-environment-variable-names).
5. Secrets used by GitHub Actions workflows (e.g., the SSH deploy key, registry credentials) **must** be stored as encrypted GitHub Actions secrets, never as plaintext repository variables or committed files.
6. `.env` files on the production server **must** be readable only by the deploy user and root (file mode `600`), not world-readable.
7. Changing a production `.env` value **must** be followed by a `docker compose up -d` to apply it; editing the file alone does not update the running container, per [ARCH-005, Section 5](../01-architecture/ARCH-005-deployment-strategy.md#5-deployment-sequence).

---

# 4. Examples

## 4.1 Compliant `.env.example`

```
DB_HOST=
DB_PORT=5432
DB_NAME=
DB_USER=
DB_PASSWORD=
REDIS_URL=
SMTP_HOST=
SMTP_PORT=587
```

## 4.2 Non-Compliant

- A `.env` file committed with `DB_PASSWORD=S3cr3tProd123` present in Git history.
- An application reading a secret from a hardcoded string in source code instead of an environment variable.

---

# 5. Rationale

This standard is the enforceable form of the Secrets boundary in [ARCH-007 — Security Architecture](../01-architecture/ARCH-007-security-architecture.md): the rule "no secret is ever committed to Git" only holds if every repository consistently uses `.env` + `.gitignore`, never inline configuration.

---

# 6. References

- [ARCH-007 — Security Architecture, Section 4.2](../01-architecture/ARCH-007-security-architecture.md#4-security-boundaries)
- [STD-001 — Compose Standard](STD-001-compose-standard.md)
- [STD-002 — Naming Convention](STD-002-naming-convention.md)
- [STD-010 — Security Standard](STD-010-security-standard.md)
