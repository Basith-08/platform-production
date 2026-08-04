# STD-002 — Naming Convention

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This standard defines naming rules for repositories, Compose services, Docker networks, Docker volumes, environment variables, and hostnames, so that any platform artifact's name reveals its ownership and purpose without additional documentation lookup.

---

# 2. Scope

Applies to every name created in `platform-production` or an application repository: repository names, `compose.yaml` service/network/volume names, `.env` variable names, and production hostnames.

---

# 3. Rules

## 3.1 Application Names

- An application's canonical name is `kebab-case`, e.g., `invoice-api`, `marketing-site`, `order-worker`.
- This canonical name is used consistently as: the repository name, the directory name under `/srv/apps/<app-name>` ([ARCH-002, Section 10](../01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping)), the GHCR image name suffix, and the Compose project name.

## 3.2 Repository Names

- Application repositories: `<app-name>` (kebab-case), optionally prefixed by organization convention (e.g., `org/invoice-api`).
- The platform repository is named `platform-production`.

## 3.3 Compose Service Names

- Service names are short, lowercase, singular nouns describing role, not implementation: `api`, `worker`, `web`, `db`, `cache`, `storage` — not `postgres-15-container` or `MyAPI`.
- A `compose.yaml` with multiple services of the same role disambiguates with a suffix: `worker-email`, `worker-report`.

## 3.4 Docker Network Names

- The shared public network is always named `edge`.
- The shared platform-service network is always named `platform-internal`.
- Every application's private network is named `<app-name>-internal`, per [ARCH-004, Section 4](../01-architecture/ARCH-004-network-architecture.md#4-rules).

## 3.5 Docker Volume Names

- Volumes are named `<app-name>-<purpose>`, e.g., `invoice-api-db-data`, `invoice-api-uploads`. Purpose is a short noun, not a technology name where the service name already implies it (prefer `db-data` over `postgres-data` when the service is already named `db`).

## 3.6 Environment Variable Names

- `UPPER_SNAKE_CASE`, always. No mixed case, no hyphens.
- Prefixed by concern where ambiguity is possible: `DB_HOST`, `DB_PASSWORD`, `REDIS_URL`, `SMTP_HOST`. Full rules in [STD-005 — Environment Variables](STD-005-environment-variables.md).

## 3.7 Hostnames

- Production hostnames follow `<app-name>.<domain>` or a documented custom domain per application. The hostname's leftmost label matches the application's canonical name wherever practical, to keep Traefik routing rules self-explanatory.

## 3.8 Documentation IDs

- Architecture documents: `ARCH-XXX` (three-digit, zero-padded, sequential).
- Architecture Decision Records: `ADR-XXXX` (four-digit, zero-padded, sequential).
- Standards: `STD-XXX` (three-digit, zero-padded, sequential).
- Operations: `OPS-XXX` (three-digit, zero-padded, sequential).
- IDs are never reused or renumbered after approval, per [ARCH-003, Section 4](../01-architecture/ARCH-003-directory-structure.md#4-documentation-structure-docs).

---

# 4. Examples

| Concept | Compliant | Non-Compliant |
|---|---|---|
| Application name | `invoice-api` | `InvoiceAPI`, `invoice_api` |
| Network | `invoice-api-internal` | `invoiceapi_net`, `net1` |
| Volume | `invoice-api-db-data` | `data`, `pgdata` |
| Env var | `DB_PASSWORD` | `dbPassword`, `db-password` |
| Hostname | `invoice-api.example.com` | `api2.example.com` (unless documented custom domain) |

---

# 5. Rationale

Consistent naming is what makes [ARCH-002, Section 10 — Directory Mapping](../01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping) and [ARCH-004 — Network Architecture](../01-architecture/ARCH-004-network-architecture.md) mechanically enforceable rather than aspirational: an operator or a script can derive an application's directory, network, and volume names from its canonical name alone.

---

# 6. References

- [ARCH-002 — Platform Architecture, Section 10](../01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping)
- [ARCH-004 — Network Architecture](../01-architecture/ARCH-004-network-architecture.md)
- [STD-003 — Repository Standard](STD-003-repository-standard.md)
- [STD-005 — Environment Variables](STD-005-environment-variables.md)
