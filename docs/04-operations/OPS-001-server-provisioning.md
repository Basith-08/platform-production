# OPS-001 — Server Provisioning

**Status:** Approved

**Version:** 1.0

**Owner:** Platform Team

**Last Updated:** 2026-07-15

---

# 1. Purpose

This procedure provisions a new production server from a bare Ubuntu 24.04 LTS instance to a state ready to run platform services and applications. It is the first step of both initial platform setup and [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md).

---

# 2. Preconditions

- A fresh Ubuntu 24.04 LTS server (VPS or bare metal) with root or sudo SSH access.
- DNS control for the domain(s) that will point at this server.
- Access to the `platform-production` repository.
- An SSH key pair designated for the platform deploy user, per [ARCH-007, Section 4.1](../01-architecture/ARCH-007-security-architecture.md#4-security-boundaries).

---

# 3. Procedure

1. **Create a non-root deploy user** and add its public key to `~/.ssh/authorized_keys`.
   ```
   adduser deploy
   usermod -aG sudo deploy
   mkdir -p /home/deploy/.ssh && chmod 700 /home/deploy/.ssh
   echo "<deploy-public-key>" >> /home/deploy/.ssh/authorized_keys
   chmod 600 /home/deploy/.ssh/authorized_keys
   chown -R deploy:deploy /home/deploy/.ssh
   ```
2. **Harden SSH**, per [STD-010, Section 3.1](../03-standards/STD-010-security-standard.md#31-access-control): in `/etc/ssh/sshd_config`, set `PasswordAuthentication no` and `PermitRootLogin no`, then `systemctl restart sshd`.
3. **Configure the firewall**, per [STD-010, Rule 4](../03-standards/STD-010-security-standard.md#31-access-control):
   ```
   ufw default deny incoming
   ufw default allow outgoing
   ufw allow 22/tcp
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```
4. **Enable automatic OS security updates**: `apt install unattended-upgrades && dpkg-reconfigure -plow unattended-upgrades`.
5. **Install Docker Engine, containerd, and the Compose plugin** from Docker's official APT repository, per [ADR-0007](../02-decisions/ADR-0007-docker-runtime.md):
   ```
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list
   apt update
   apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin
   usermod -aG docker deploy
   ```
6. **Create the directory layout**, per [ARCH-002, Section 10](../01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping):
   ```
   mkdir -p /srv/platform/{traefik,monitoring,backup,networks}
   mkdir -p /srv/apps
   chown -R deploy:deploy /srv/platform /srv/apps
   ```
7. **Clone `platform-production`** into a working location (not `/srv`, which holds only runtime state per [ARCH-002, Section 10](../01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping)):
   ```
   git clone https://github.com/<org>/platform-production.git ~/platform-production
   ```
8. **Create shared Docker networks**, per [ARCH-004, Section 4](../01-architecture/ARCH-004-network-architecture.md#4-rules):
   ```
   docker network create edge
   docker network create platform-internal
   ```
9. **Populate each platform service's `.env`** from its `.env.example` (`infrastructure/traefik/.env.example`, `infrastructure/monitoring/.env.example`) directly on the server at `/srv/platform/<component>/.env`, mode `600` — this step cannot be automated, since a populated `.env` is never committed to Git, per [STD-005](../03-standards/STD-005-environment-variables.md).
10. **Add the deploy key as a GitHub Actions secret** (`PROD_HOST`, `PROD_DEPLOY_USER`, `PROD_DEPLOY_KEY`) on the `platform-production` repository itself, and on every application repository that will deploy to this server.
11. **Deploy platform services** (Traefik, Beszel, Uptime Kuma, backup automation) from `infrastructure/` by pushing to `platform-production`'s `main` branch (or running the `Deploy Platform` workflow manually with no `component` input, to deploy every component at once for this first run) — see [OPS-011 — Deploy Platform Service](OPS-011-deploy-platform-service.md). This replaces running `docker compose up -d` by hand; the manual command remains available only as the emergency path in [OPS-011, Section 3.4](OPS-011-deploy-platform-service.md#34-manual--emergency-path).
12. **Point DNS** for every platform-service hostname (e.g., monitoring dashboards) at the server's public IP.

---

# 4. Verification

- `ssh deploy@<server>` succeeds with key-based auth; password auth attempts are refused.
- `docker compose version` and `docker network ls` show `edge` and `platform-internal`.
- Traefik responds on `https://<platform-domain>` with a valid TLS certificate.
- Beszel and Uptime Kuma dashboards are reachable through Traefik and require authentication.

---

# 5. Rollback / Failure Handling

If provisioning fails partway through, re-running this procedure from the failed step is safe — every step is idempotent (user creation, package installation, directory creation, and network creation all no-op or safely update on re-run). If the server is unrecoverable, discard it and re-provision a new instance from Step 1; no state on a partially-provisioned server is depended upon elsewhere.

---

# 6. References

- [ARCH-002 — Platform Architecture, Section 10](../01-architecture/ARCH-002-platform-architecture.md#10-directory-mapping)
- [ARCH-006 — Runtime Architecture](../01-architecture/ARCH-006-runtime-architecture.md)
- [ARCH-007 — Security Architecture](../01-architecture/ARCH-007-security-architecture.md)
- [STD-005 — Environment Variables](../03-standards/STD-005-environment-variables.md)
- [STD-010 — Security Standard](../03-standards/STD-010-security-standard.md)
- [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md)
- [OPS-011 — Deploy Platform Service](OPS-011-deploy-platform-service.md)
