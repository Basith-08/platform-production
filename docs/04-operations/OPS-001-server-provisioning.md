# OPS-001 — Server Provisioning

**Status:** Approved

**Version:** 1.1

**Owner:** Platform Team

**Last Updated:** 2026-08-20

---

# 1. Purpose

Provision a fresh Ubuntu 24.04 LTS VPS into a platform-ready Docker runtime
without putting a repository clone or application source code on the server.
Provisioning and SSH hardening are separate phases so a failed installation
does not lock out root or console recovery access.

# 2. Preconditions

- A fresh Ubuntu 24.04 LTS, `linux/amd64` server with provider console/root access.
- A separate SSH key pair for the human `admin` account and for CI/CD `deploy`.
- The bootstrap directory copied to the server through a trusted console or
  workstation transfer. The server does not need a permanent
  `platform-production` clone.
- DNS control and access to GitHub repository secrets.

# 3. Procedure

## 3.1 Prepare and transfer bootstrap

1. Generate two key pairs on a trusted workstation. Keep private keys off the
   server and never commit them:

   ```text
   prod-sby-01-admin       -> human/operator SSH
   prod-sby-01-deploy      -> GitHub Actions SSH
   ```

2. Transfer `infrastructure/automation/bootstrap.sh`,
   `infrastructure/automation/install-rclone.sh`, and
   `infrastructure/automation/platform-doctor.sh`, plus both public keys, to a
   root-only directory such as `/root/bootstrap/` using the provider console or
   an already trusted root session.

## 3.2 Provision phase

Run as root:

```bash
/root/bootstrap/bootstrap.sh provision \
  --hostname prod-sby-01 \
  --admin-key /root/bootstrap/prod-sby-01-admin.pub \
  --deploy-key /root/bootstrap/prod-sby-01-deploy.pub
```

The phase validates Ubuntu/architecture, DNS, keys, users, packages, pinned
rclone `1.75.0`, Docker/Compose, UFW, directories, journald, and logrotate.
It creates:

- `admin`: human/operator account, sudo group, personal key. Set its local
  password from the provider console with `passwd admin` so standard sudo can
  authenticate.
- `deploy`: CI account, deploy key, Docker group, no password and no general
  sudo membership. Docker-group membership is effectively root-equivalent;
  removing sudo does not make this account unprivileged.

Provision completion writes `/var/lib/platform/provisioned`. It does **not**
disable root SSH, password authentication, or reload SSH.

## 3.3 Verify access, then harden SSH

1. Run the read-only host report:

   ```bash
   /root/bootstrap/platform-doctor.sh host
   ```

2. From new workstation terminals, verify both accounts:

   ```bash
   ssh -i prod-sby-01-admin admin@<server>
   ssh -i prod-sby-01-deploy deploy@<server> 'docker compose version'
   ```

3. After both sessions work, from the root/console session run:

   ```bash
   /root/bootstrap/bootstrap.sh harden
   ```

   The command writes a drop-in, runs `/usr/sbin/sshd -t`, restores the
   previous drop-in on syntax failure, reloads `ssh.service`, and verifies the
   effective SSH settings. It uses reload rather than restart.

4. Open new admin and deploy sessions again. Root SSH and password SSH must now
   be refused while key-based access remains available.

## 3.4 Record host identity and configure access

1. From the provider console, record the fingerprint of the host public key:

   ```bash
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. From a trusted workstation, obtain the host-key line with `ssh-keyscan` and
   compare its fingerprint with the console result. Store the verified line(s)
   as the protected GitHub secret `PROD_KNOWN_HOSTS`. Workflows must use this
   value; they must not learn a new production key during deployment.

3. Configure these secrets on the `platform-production` repository and each
   application repository that deploys to this host:

   ```text
   PROD_HOST
   PROD_DEPLOY_USER=deploy
   PROD_DEPLOY_KEY=<private CI key>
   PROD_KNOWN_HOSTS=<verified known_hosts entry>
   ```

   Keep the human private key separate from the CI secret. A host rebuild or
   migration requires an intentional fingerprint review and secret update.

## 3.5 Runtime configuration and deployment

1. Populate runtime files out of band, all mode `600` and owned by `deploy`:
   platform `.env` files, backup files/key, rclone config, Traefik generated
   credentials, and application `.env` files. Use [OPS-013](OPS-013-manual-configuration-inventory.md).
2. Run the backup preflight after configuring the rclone OAuth/config:

   ```bash
   /srv/platform/backup/backup-doctor.sh
   ```

3. Run the `Deploy Platform` workflow. A full deployment always runs
   `networks` first; Traefik and monitoring then run independently. Do not
   manually create shared networks during the normal path.
4. Run:

   ```bash
   /srv/platform/automation/platform-doctor.sh full
   ```

5. Configure DNS/TLS, monitoring accounts, backup OAuth/key, and application
   routing as described by the relevant OPS runbooks.

# 4. Node identity and DNS

`prod-sby-01` is the Linux hostname and deterministic node identity. It does
not need to resolve publicly. DNS application hostnames such as
`api.example.com`, and the platform domain used by Traefik, are separate
configuration concerns and may point to the node independently.

# 5. Existing host migration

Do not run provisioning automatically from `deploy-platform.yml`. The existing
host may continue using its current `deploy` access until an operator performs
an explicit migration: create/test `admin`, install its separate key, verify
sudo, review/remove any `deploy` sudo membership, record `PROD_KNOWN_HOSTS`,
then harden/reload SSH. Platform deployment only syncs `/srv/platform` files
and never changes users, sudoers, or sshd configuration.

# 6. Rollback / failure handling

If `provision` fails, the structured report identifies the step, line, command,
and exit code. Until the provision marker exists and `harden` completes, the
host is intentionally not SSH-hardened; use the root/console path to correct
the issue and rerun `provision`. Reruns preserve users, keys, `/srv` data,
Docker state, and runtime files. A failed `harden` syntax check restores the
previous drop-in and does not reload an invalid configuration.

# 7. References

- [ARCH-002 — Platform Architecture](../01-architecture/ARCH-002-platform-architecture.md)
- [ARCH-007 — Security Architecture](../01-architecture/ARCH-007-security-architecture.md)
- [STD-005 — Environment Variables](../03-standards/STD-005-environment-variables.md)
- [STD-010 — Security Standard](../03-standards/STD-010-security-standard.md)
- [OPS-009 — Disaster Recovery](OPS-009-disaster-recovery.md)
- [OPS-011 — Deploy Platform Service](OPS-011-deploy-platform-service.md)
- [OPS-013 — Manual Configuration Inventory](OPS-013-manual-configuration-inventory.md)
