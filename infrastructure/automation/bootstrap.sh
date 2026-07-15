#!/usr/bin/env bash
#
# Bootstraps a fresh Ubuntu 24.04 LTS server into a platform-ready host:
# deploy user, SSH hardening, firewall, Docker runtime, and directory layout.
#
# This script implements docs/04-operations/OPS-001-server-provisioning.md,
# Steps 1-6. Run as root on a brand-new server. Idempotent where practical.
#
# Reference: docs/04-operations/OPS-001-server-provisioning.md
#            docs/02-decisions/ADR-0007-docker-runtime.md

set -euo pipefail

DEPLOY_USER="deploy"
DEPLOY_PUBKEY="${1:?Usage: bootstrap.sh <path-to-deploy-public-key>}"

echo "==> Creating deploy user"
id -u "${DEPLOY_USER}" &>/dev/null || adduser --disabled-password --gecos "" "${DEPLOY_USER}"
usermod -aG sudo "${DEPLOY_USER}"
mkdir -p "/home/${DEPLOY_USER}/.ssh"
cp "${DEPLOY_PUBKEY}" "/home/${DEPLOY_USER}/.ssh/authorized_keys"
chmod 700 "/home/${DEPLOY_USER}/.ssh"
chmod 600 "/home/${DEPLOY_USER}/.ssh/authorized_keys"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"

echo "==> Hardening SSH"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

echo "==> Configuring firewall"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> Enabling automatic security updates"
apt-get update -y
apt-get install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> Installing Docker Engine, containerd, and Compose plugin"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
# shellcheck disable=SC1091  # /etc/os-release only exists on the target host, not in lint environments
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker "${DEPLOY_USER}"

echo "==> Creating platform directory layout"
mkdir -p /srv/platform/{traefik,monitoring,backup,networks}
mkdir -p /srv/apps
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" /srv/platform /srv/apps

echo "==> Bootstrap complete. Continue with docs/04-operations/OPS-001-server-provisioning.md, Step 7."
